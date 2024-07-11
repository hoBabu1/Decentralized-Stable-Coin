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
    uint256 public constant STARTING_ERC20_Balance = 100 ether;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscBrain, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_Balance);
    }
    /* EVENT */

    event tokenDepositedSuccessFully(address indexed tokenAddress, uint256 indexed amount);

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

    modifier depositColletralAndMintDSC(){
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscBrain), AMOUNT_COLLETRAL);
        dscBrain.depositColletralAndMintDSC(weth , AMOUNT_COLLETRAL , 5e18);
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
        (uint256 totalDscMinted, uint256 totalValueInUsd) = dscBrain.get_getAccountInfoOfUser(USER);
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

    function testdepositColletralAndMintDSC() public depositColletralAndMintDSC() {
        (uint256 totalDscMinted, uint256 totalValueInUsd) = dscBrain.get_getAccountInfoOfUser(USER);
        console.log(totalDscMinted);
         

    }
    
}
