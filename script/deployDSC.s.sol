//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import {Script} from "lib/forge-std/src/Script.sol";
import {DecentralizedStableCoin} from "src/decentralizedStableCoin.sol";
import {DSCBrain} from "src/DSCBrain.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployDSC is Script {

  address[] public tokenAddress;
  address[] public  tokenToPriceFeedAddress;
    function run() external returns (DecentralizedStableCoin , DSCBrain , HelperConfig) {
      HelperConfig helperConfig = new HelperConfig();
      (address wethUsdPriceFeed,
        address wbtcUsdPriceFeed,
        address weth,
        address wbtc,
        uint256 deployerKey) = helperConfig.activeNetworkConfig();
        tokenAddress = [weth,wbtc];
        tokenToPriceFeedAddress = [wethUsdPriceFeed,wbtcUsdPriceFeed];

        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCBrain dscBrain = new DSCBrain(tokenAddress,tokenToPriceFeedAddress,address(dsc));

        dsc.transferOwnership(address(dscBrain));
        vm.stopBroadcast();
        return (dsc,dscBrain,helperConfig);
    }
}
