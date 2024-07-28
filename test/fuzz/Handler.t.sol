/* It will narrow down the way we call function 
   Benifit -- This way we dont waste  runs */

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralizedStableCoin} from "src/decentralizedStableCoin.sol";
import {DSCBrain} from "src/DSCBrain.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    DecentralizedStableCoin dsc;
    DSCBrain dscBrain;
    ERC20Mock wbtc;
    ERC20Mock weth;
    uint256 public  timesMointIsCalled ;
    uint256 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    address [] public userWithColletralDeposited;
    constructor(DecentralizedStableCoin _dsc, DSCBrain _dscBrain) {
        dsc = _dsc;
        dscBrain = _dscBrain;
        address[] memory colletralToken = dscBrain.getColletralToken();
        wbtc = ERC20Mock(colletralToken[1]);
        weth = ERC20Mock(colletralToken[0]);
    }

    // reedem colletral ->  call this when u have colletral  - for this we need to deposit colletral
    function mintDsc(uint256 amount, uint256 addressSeed ) public 
    {
        if(userWithColletralDeposited.length == 0)
        {
            return;
        }
        address sender = userWithColletralDeposited[addressSeed%userWithColletralDeposited.length];
        (uint256 totalDscMinted, uint256 totalValueInUsd) = dscBrain.get_getAccountInfoOfUser(sender);
        int256 maxDscToMint = (int256(totalValueInUsd)/2) - int256(totalDscMinted);

        if(maxDscToMint < 0)
        {
            return;
        }
        amount = bound(amount , 0 , uint256(maxDscToMint));

        if(amount == 0)
        {
            return ;
        }
        vm.startPrank(sender);
        dscBrain.mintDSC(amount);
        vm.stopPrank();
        timesMointIsCalled++; 
    }
    function depositColletral(uint256 colletralSeed, uint256 amountColletral) public {
        amountColletral = bound(amountColletral,1,MAX_DEPOSIT_SIZE);
        ERC20Mock colletral = _getColletralFromSeed(colletralSeed);
        vm.startPrank(msg.sender);
        ERC20Mock(colletral).mint(msg.sender, amountColletral);
        colletral.approve(address(dscBrain), amountColletral);
        dscBrain.depositColletral(address(colletral), amountColletral);
        vm.stopPrank();
        userWithColletralDeposited.push(msg.sender);
    }

   

    function redeemColletral(uint256 colletralSeed,uint256 amountColletral) public 
    {
        ERC20Mock colletral = _getColletralFromSeed(colletralSeed);
        uint256 maxColletralToRedeem = dscBrain.getColletralDeposited(address(colletral) , msg.sender);
        if(maxColletralToRedeem == 0)
        {
            return;
        }
        amountColletral = bound(amountColletral,1,maxColletralToRedeem);
        dscBrain.redeemColletral(address(colletral), amountColletral);
    }
    /** Helper function */
    function _getColletralFromSeed(uint256 colletralSeed) private view returns (ERC20Mock) {
        if (colletralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
