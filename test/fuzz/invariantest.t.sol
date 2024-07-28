//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;
import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralizedStableCoin} from "src/decentralizedStableCoin.sol";
import {DSCBrain} from "src/DSCBrain.sol";
import {DeployDSC} from "script/deployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Handler} from "test/fuzz/Handler.t.sol";
contract OpenInvariantsTest is StdInvariant,Test 
{
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCBrain dscBrain;
    HelperConfig helperConfig;
     address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    Handler handler ;
    function setUp() external {
         deployer = new DeployDSC();
        (dsc, dscBrain, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
       // targetContract(address(dscBrain));
         handler = new Handler(dsc , dscBrain);
         targetContract(address(handler));
    }
    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view
    {
        uint256  totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscBrain));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dscBrain));
        
        console.log("Total supply",totalSupply);
        console.log("Total eth",totalWethDeposited);
        console.log("Total btc",totalBtcDeposited);
        console.log("Times Mint is called " , handler.timesMointIsCalled());
        uint256 totalwethUsdValue = dscBrain.getValueInUSD(address(weth),totalWethDeposited);
        uint256 totalWbtcValueInUsd = dscBrain.getValueInUSD(address(wbtc),totalBtcDeposited);
        assert(totalwethUsdValue+totalWbtcValueInUsd >= totalSupply);
    }
}

