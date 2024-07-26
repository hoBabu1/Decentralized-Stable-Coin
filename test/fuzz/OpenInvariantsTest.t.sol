// // contain properties which always hold true . 
// /**
//  * What are our invariants ?
//  * 1. Total supply of DSC should be less than the total value of colletral 
//  * 2. Getter view function should never revert -> evergreen invariant 
//  */

// //SPDX-License-Identifier:MIT

// pragma solidity ^0.8.0;
// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DecentralizedStableCoin} from "src/decentralizedStableCoin.sol";
// import {DSCBrain} from "src/DSCBrain.sol";
// import {DeployDSC} from "script/deployDSC.s.sol";
// import {HelperConfig} from "script/HelperConfig.s.sol";
// import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// contract OpenInvariantsTest is StdInvariant,Test 
// {
//     DeployDSC deployer;
//     DecentralizedStableCoin dsc;
//     DSCBrain dscBrain;
//     HelperConfig helperConfig;
//      address wethUsdPriceFeed;
//     address wbtcUsdPriceFeed;
//     address weth;
//     address wbtc;
//     function setUp() external {
//          deployer = new DeployDSC();
//         (dsc, dscBrain, helperConfig) = deployer.run();
//         (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
//         targetContract(address(dscBrain));
//     }
//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view
//     {
//         uint256  totalSupply = dsc.totalSupply();
//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscBrain));
//         uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dscBrain));

//         uint256 totalwethUsdValue = dscBrain.getValueInUSD(address(weth),totalWethDeposited);
//         uint256 totalWbtcValueInUsd = dscBrain.getValueInUSD(address(wbtc),totalBtcDeposited);
//         assert(totalwethUsdValue+totalWbtcValueInUsd >= totalSupply);
//     }
// }

