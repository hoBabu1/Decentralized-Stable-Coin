//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/decentralizedStableCoin.sol";
import {DSCBrain} from "src/DSCBrain.sol";
import {DeployDSC} from "script/deployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DscBrainTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCBrain dscBrain;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address weth;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscBrain, helperConfig) = deployer.run();
        (ethUsdPriceFeed,,weth, , ) = helperConfig.activeNetworkConfig();
    }

    ////////////////
    // PriceFeed////
    ////////////////
    function testgetValueUsd() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dscBrain.getValueInUSD(weth,ethAmount);
        assertEq(expectedUsd,actualUsd);
    }
}
