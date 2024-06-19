//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/decentralizedStableCoin.sol";
import {DSCBrain} from "src/DSCBrain.sol";
import {DeployDSC} from "script/deployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

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
        (wethUsdPriceFeed,wbtcUsdPriceFeed,weth,wbtc , ) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER,STARTING_ERC20_Balance);
        
    }

    modifier depositColletral()
    {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscBrain),AMOUNT_COLLETRAL);
        dscBrain.depositColletral(weth , AMOUNT_COLLETRAL);
        vm.stopPrank();
        _;
    }

    ////////////////////////
    // Constructor Test ////
    ///////////////////////
    address[] public tokenAddress ;
    address[] public priceFeedAddress;
    function testRevertIfTokenLengthDosentMatchPriceFeedLengthCorrectly() public {
        tokenAddress.push(weth);
        priceFeedAddress.push(wethUsdPriceFeed);
        priceFeedAddress.push(wbtcUsdPriceFeed);
        vm.expectRevert(DSCBrain.DSCBrain__ProblemWithTokenAddressAndPriceFeedAddress.selector);
        new DSCBrain(tokenAddress,priceFeedAddress,address(dsc));
    }

    /////////////////
    // PriceFeed ////
    ////////////////
    function testgetValueUsd() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dscBrain.getValueInUSD(weth,ethAmount);
        assertEq(expectedUsd,actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether ;
        uint256 expectedEth = 0.05 ether;
        uint256 actualEth = dscBrain.getTokenAmountFromUsd(weth ,usdAmount );
        assertEq(expectedEth , actualEth);

    }

    ///////////////////////////////////////
    // DEPOSIT COLLETRAL TEST ////////////
    /////////////////////////////////////
    function testRevertIfColletralIsZero() public {
       vm.startPrank(USER);
       ERC20Mock(weth).approve(address(dscBrain),AMOUNT_COLLETRAL);
       vm.expectRevert(DSCBrain.DSCBrain__enteredAmountShouldBeMoreThanZero.selector);
       dscBrain.depositColletral(weth,0);
       vm.stopPrank();
    }

    function testRevertIfTokenIsNotAllowed() public 
    {
        ERC20Mock erc20Mock = new ERC20Mock("Temp","Temp" , USER , AMOUNT_COLLETRAL);
        vm.startPrank(USER);
        ERC20Mock(erc20Mock).approve(address(dscBrain),AMOUNT_COLLETRAL);
        vm.expectRevert(DSCBrain.DSCBrain__thisTokenIsNotAllowed.selector);
        dscBrain.depositColletral(address(erc20Mock),AMOUNT_COLLETRAL);
        vm.stopPrank();
    }

    function testUserIsGettingRegisteredInAccount() public depositColletral(){
        uint256 depositedAmount = dscBrain.getColletralDeposited(USER,address(weth));
        assertEq(depositedAmount,AMOUNT_COLLETRAL);

    }

    

}
