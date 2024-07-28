//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/decentralizedStableCoin.sol";
import {DSCBrain} from "src/DSCBrain.sol";
import {DeployDSC} from "script/deployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockFailedTransferFrom} from "test/unit/mocks/mockFailedTransferFrom.sol";
import {MockMintingFail} from "test/unit/mocks/MockFailedMint.sol";
import {MockTransferFailReedeem} from "test/unit/mocks/MockTransferFailReedeem.sol";
import {MockV3Aggregator} from "test/unit/mocks/mockV3Aggregator.sol";

contract DscBrainTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCBrain dscBrain;
    HelperConfig helperConfig;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    address public newAddress = makeAddr("Namaste");
    address public USER = makeAddr("hoBabu");
    uint256 public constant AMOUNT_COLLETRAL = 10 ether;
    uint256 public constant STARTING_ERC20_Balance = 10 ether;

     // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 200 ether;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscBrain, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_Balance);
    }
    /* EVENT */

    event tokenDepositedSuccessFully(address indexed tokenAddress, uint256 indexed amount);
    event colletralReedemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed tokenColletralAddress, uint256 amount
    );

    ////////////////////
    // Modifier ////////
    ////////////////////
    modifier depositColletral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscBrain), AMOUNT_COLLETRAL);
        dscBrain.depositColletral(weth, AMOUNT_COLLETRAL);
        vm.stopPrank();
        _;
    }

    modifier depositColletralAndMintDSC() {
        uint256 amountToMint= 100e18;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscBrain), AMOUNT_COLLETRAL);
        dscBrain.depositColletralAndMintDSC(weth, AMOUNT_COLLETRAL, amountToMint);
        vm.stopPrank();
        _;
    }

    ////////////////////////
    // Constructor Test ////
    ///////////////////////
    address[] public tokenAddress;
    address[] public priceFeedAddress;

    function testRevertIfTokenLengthDosentMatchPriceFeedLengthCorrectly() public {
        tokenAddress.push(weth);
        priceFeedAddress.push(wethUsdPriceFeed);
        priceFeedAddress.push(wbtcUsdPriceFeed);
        vm.expectRevert(DSCBrain.DSCBrain__ProblemWithTokenAddressAndPriceFeedAddress.selector);
        new DSCBrain(tokenAddress, priceFeedAddress, address(dsc));
    }

    /////////////////
    // PriceFeed ////
    ////////////////
    function testgetValueUsd() public view {
        uint256 ethAmount = 15 ether;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dscBrain.getValueInUSD(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedEth = 0.05 ether;
        uint256 actualEth = dscBrain.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedEth, actualEth);
    }

    ///////////////////////////////////////
    // DEPOSIT COLLETRAL TEST ////////////
    /////////////////////////////////////
    function testRevertIfColletralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscBrain), AMOUNT_COLLETRAL);
        vm.expectRevert(DSCBrain.DSCBrain__enteredAmountShouldBeMoreThanZero.selector);
        dscBrain.depositColletral(weth, 0);
        vm.stopPrank();
    }

    function testRevertIfTokenIsNotAllowed() public {
        ERC20Mock erc20Mock = new ERC20Mock("Temp", "Temp", USER, AMOUNT_COLLETRAL);
        vm.startPrank(USER);
        ERC20Mock(erc20Mock).approve(address(dscBrain), AMOUNT_COLLETRAL);
        vm.expectRevert(DSCBrain.DSCBrain__thisTokenIsNotAllowed.selector);
        dscBrain.depositColletral(address(erc20Mock), AMOUNT_COLLETRAL);
        vm.stopPrank();
    }

    function testUserIsGettingRegisteredInAccount() public depositColletral {
        uint256 depositedAmount = dscBrain.getColletralDeposited(USER, address(weth));
        assertEq(depositedAmount, AMOUNT_COLLETRAL);
    }

    function testEmitEventWhenUserDepositCOlletral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscBrain), AMOUNT_COLLETRAL);
        vm.expectEmit(true, false, false, false, address(dscBrain));
        emit DSCBrain.tokenDepositedSuccessFully(weth, AMOUNT_COLLETRAL);
        dscBrain.depositColletral(weth, AMOUNT_COLLETRAL);
        vm.stopPrank();
    }

    function testRevertIfTransactionIsFail() public {
        vm.startPrank(USER);
        MockFailedTransferFrom mockCoin = new MockFailedTransferFrom();
       
        tokenAddress.push(address(mockCoin));
        priceFeedAddress.push(wethUsdPriceFeed);
        DSCBrain brainMock = new DSCBrain(tokenAddress, priceFeedAddress, address(mockCoin));
        mockCoin.mint(USER, AMOUNT_COLLETRAL);

        mockCoin.transferOwnership(address(brainMock));

        ERC20Mock(address(mockCoin)).approve(address(brainMock), AMOUNT_COLLETRAL);
        vm.expectRevert(DSCBrain.DSCBrain__TransferOfTokenFailedFromUserToContract.selector);
        brainMock.depositColletral(address(mockCoin), AMOUNT_COLLETRAL);
        vm.stopPrank();
    }

    function testGetColletralDeposited() public depositColletral {
        uint256 balance = dscBrain.getColletralDeposited(USER, weth);
        assertEq(balance, AMOUNT_COLLETRAL);
    }

    function testGetAccountColletralValue() public depositColletral {
        uint256 colletralValue = dscBrain.getAccountColletralValue(USER);
        assertEq(colletralValue, 20000e18);
    }

    function testget_getAccountInfoOfUser() public depositColletral {
        uint256 userDscMinted = 0;
        uint256 userValueInUsd = 20000e18;
        (uint256 totalDscMinted, uint256 totalValueInUsd) = dscBrain.get_getAccountInfoOfUser(USER);
        assertEq(totalDscMinted, userDscMinted);
        assertEq(userValueInUsd, totalValueInUsd);
    }

    ///////////////////////
    // Mint DSC //////////
    /////////////////////

    function test_MintDsc_GreaterThan_Zero() public depositColletral {
        vm.startPrank(USER);
        vm.expectRevert(DSCBrain.DSCBrain__enteredAmountShouldBeMoreThanZero.selector);
        dscBrain.mintDSC(0);
        vm.stopPrank();
    }

    function testHealthFactorMaxIfDscMintedIsZero() public depositColletral {
        vm.startPrank(USER);
        uint256 healthfactor = dscBrain.getHealthFactor(USER);
        assertEq(type(uint256).max, healthfactor);
        vm.stopPrank();
    }

    function testUserCanMintDSC() public depositColletral {
        vm.startPrank(USER);
        uint256 amountOfDscToMint = 5;
        dscBrain.mintDSC(amountOfDscToMint);
        (uint256 totalDscMinted,) = dscBrain.get_getAccountInfoOfUser(USER);
        assertEq(totalDscMinted, amountOfDscToMint);
        vm.stopPrank();
    }

    function testRevertIfHealthFactorIsBroken() public depositColletral {
        /**
         * Get the total amount value of User in USD .
         * As per the logic in DSCEngine -- system need to be 200% overcolletralized.
         * It means that we can mint only 50% of total colletral.
         * So i am getting the total value of colletral of a user in USD and dividing it by 2 --
         * It will give me the total value of of which i can mint token .
         */
        vm.startPrank(USER);
        (, uint256 totalValueInUsd) = dscBrain.get_getAccountInfoOfUser(USER);
        // As of now user havent minted any Token.
        uint256 amountOfDscUserCanMint = totalValueInUsd / 2;
        // If i increase "amountOfDscUserCanMint" , User should not be able to mint and revert
        uint256 amountOfDsc = amountOfDscUserCanMint + 1;
        uint256 expectedHealthFactor = dscBrain.calculateHealthFactor(amountOfDsc, totalValueInUsd);
        vm.expectRevert(abi.encodeWithSelector(DSCBrain.DSCBrain__HealthFactorIsBroken.selector, expectedHealthFactor));
        dscBrain.mintDSC(amountOfDsc);
        vm.stopPrank();
    }

    function testMintFail() public {
        MockMintingFail mockCoin = new MockMintingFail();
        tokenAddress.push(weth);
        priceFeedAddress.push(wethUsdPriceFeed);
        address owner = msg.sender;
        vm.prank(owner);
        DSCBrain brainMock = new DSCBrain(tokenAddress, priceFeedAddress, address(mockCoin));
        mockCoin.transferOwnership(address(brainMock));
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(brainMock), AMOUNT_COLLETRAL);
        vm.expectRevert(DSCBrain.DSCBrain__MintFailed.selector);
        brainMock.depositColletralAndMintDSC(weth, AMOUNT_COLLETRAL, 1e18);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositColletralAndMintDSC {
        (uint256 totalDscMinted, ) = dscBrain.get_getAccountInfoOfUser(USER);
        assertEq(totalDscMinted, 100e18);
    }

    ////////////////////////////////////////////
    ////// BURN DSC ///////////////////////////
    //////////////////////////////////////////
     
     function test_Amount_Of_DscToBurn_GreaterThanZero() public depositColletralAndMintDSC()
     {
        vm.startPrank(USER);
        vm.expectRevert(DSCBrain.DSCBrain__enteredAmountShouldBeMoreThanZero.selector);
        dscBrain.burnDsc(0);
        vm.stopPrank();
     }

     function testBurnDscSuccessfully() public depositColletralAndMintDSC()
     {
        uint256 userTotalDscAfterBurning = 99e18;
        vm.startPrank(USER);
        dsc.approve(address(dscBrain),1e18 );
        dscBrain.burnDsc(1e18);
        (uint256 totalDscMinted, ) = dscBrain.get_getAccountInfoOfUser(USER);
        assertEq(totalDscMinted,userTotalDscAfterBurning);
        vm.stopPrank();
     }

     function testCantBurnMoreThanUserHas() public depositColletralAndMintDSC(){
        vm.startPrank(USER);
        dsc.approve(address(dscBrain),10e18 );
        vm.expectRevert();
        dscBrain.burnDsc(11e18);
        vm.stopPrank();
     }

     ////////////////////////////
     // Reedem Colletral Test////
     ////////////////////////////
     function testRedeemColletralGreaterThanZero() public depositColletralAndMintDSC(){
        uint256 reedeemColletralAmount = 5 ether;
        vm.startPrank(USER);
        dsc.approve(address(dscBrain), reedeemColletralAmount);
        vm.expectRevert(DSCBrain.DSCBrain__enteredAmountShouldBeMoreThanZero.selector);
        dscBrain.redeemColletral(weth,0);
        vm.stopPrank();
     }

     function testUserCanReedeemColletral() public depositColletral(){
        uint256 reedeemColletralAmount = 5 ether;
        vm.startPrank(USER);
        dscBrain.redeemColletral(weth,reedeemColletralAmount);
        vm.stopPrank();
     }

     function testCannotReedemColletralMoreThanUserHave() public depositColletral(){
        uint256 reedeemColletralAmount = AMOUNT_COLLETRAL+1;
        vm.startPrank(USER);
        vm.expectRevert();
        dscBrain.redeemColletral(weth,reedeemColletralAmount);
        vm.stopPrank();
     }

     function testEmitEventOnReedeemingColletral() public depositColletral()
     {
        vm.startPrank(USER);
        vm.expectEmit(true, true , true , true , address(dscBrain));
        emit DSCBrain.colletralReedemed(USER,USER,weth,AMOUNT_COLLETRAL);
        dscBrain.redeemColletral(weth,AMOUNT_COLLETRAL);
        vm.stopPrank();
     }

     function testTransferOfRedeemingColletralFails() public {
        address owner = msg.sender ;
        vm.prank(owner);
        MockTransferFailReedeem mockCoin = new MockTransferFailReedeem();
        mockCoin.mint(USER,AMOUNT_COLLETRAL);
        
        tokenAddress.push(address(mockCoin));
        priceFeedAddress.push(wethUsdPriceFeed);
        
        vm.prank(owner);
        DSCBrain brainMock = new DSCBrain(tokenAddress, priceFeedAddress, address(mockCoin));
       
        vm.prank(owner); 
        mockCoin.transferOwnership(address(brainMock));
        vm.startPrank(USER);
        MockTransferFailReedeem(mockCoin).approve(address(brainMock),AMOUNT_COLLETRAL);
        brainMock.depositColletral(address(mockCoin),AMOUNT_COLLETRAL);

        vm.expectRevert(DSCBrain.DSCBrain__transferredFailed.selector);
        brainMock.redeemColletral(address(mockCoin),AMOUNT_COLLETRAL);
        vm.stopPrank();
      }
      //////////////////////////////////
      //// Redeem Colletral For Dsc////
      /////////////////////////////////

      function testRedeemMoreThanZero() public depositColletralAndMintDSC()
      {
        vm.startPrank(USER);
        dsc.approve(address(dscBrain),AMOUNT_COLLETRAL);
        vm.expectRevert(DSCBrain.DSCBrain__enteredAmountShouldBeMoreThanZero.selector);
        dscBrain.redeemColletralForDsc(weth,AMOUNT_COLLETRAL,0);
        vm.stopPrank();

      }
      function testRedeemColletralForDsc() public depositColletralAndMintDSC()
      {
        vm.startPrank(USER);
        dsc.approve(address(dscBrain),100e18);
        dscBrain.redeemColletralForDsc(weth,AMOUNT_COLLETRAL,100e18);
        (uint256 totalDscMinted, ) = dscBrain.get_getAccountInfoOfUser(USER);
        assertEq(totalDscMinted,0);
        vm.stopPrank();
      } 

      ////////////////////////////////////////
      ////// Health Factor //////////////////
      ///////////////////////////////////////

      function testHealthFactor() public depositColletralAndMintDSC()
      {
        uint256 expectedHealthFactor = 100e18;
        uint256 orginalHealthFactor = dscBrain.getHealthFactor(USER);
        assertEq(expectedHealthFactor,orginalHealthFactor);
      }

      //////////////////////////////////
      // Liquidation Test //////////////
      //////////////////////////////////

      function testDebtCoverShouldBeMoreThanZero() public depositColletralAndMintDSC()
      {
        vm.startPrank(USER);
        vm.expectRevert(DSCBrain.DSCBrain__enteredAmountShouldBeMoreThanZero.selector);
        dscBrain.liquidate(weth, USER , 0);
        vm.stopPrank();
      }
      function testRevertIfHealthFactorIsOk() public depositColletralAndMintDSC()
      {
        uint256 debtToCover = 1 ;
        vm.startPrank(USER);
        vm.expectRevert(DSCBrain.DSCBrain__HealthFactorIsOk.selector);
        dscBrain.liquidate(weth, USER , debtToCover);
        vm.stopPrank();
      }

      function testLiquidation() public depositColletralAndMintDSC(){
          //uint256 beforeHealthFactor =  dscBrain.getHealthFactor(USER);
         // console.log("Before",beforeHealthFactor);
          int256 ethUsdUpdatedPrice = 10e8;
          MockV3Aggregator(wethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
          //uint256 afterHealthFactor =  dscBrain.getHealthFactor(USER);
          //console.log("After",afterHealthFactor);
          ERC20Mock(weth).mint(liquidator,collateralToCover);
          vm.startPrank(liquidator);
          ERC20Mock(weth).approve(address(dscBrain),collateralToCover);
          dscBrain.depositColletralAndMintDSC(weth,collateralToCover,10e18);
          dsc.approve(address(dscBrain),10e18);
          (uint256 totalDscMinted, uint256 totalValueInUsd) = dscBrain.get_getAccountInfoOfUser(liquidator);
          console.log("Liquidator ",totalValueInUsd);
          dscBrain.liquidate(weth,USER,10e18);
          vm.stopPrank();
          (uint256 totalDscMinted1, uint256 totalValueInUsd1) = dscBrain.get_getAccountInfoOfUser(liquidator);
          console.log("Liquidator ",totalValueInUsd1);
      }
}
