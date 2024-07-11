//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

/**
 * Why ERC20Burnable ?
 * It has burn function function , it will help to maintain the pegged price
 */
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/**
 * @title Decentralized Stable Coin
 * @author hoBabu aka Aman kumar
 * Colletral : Exogenous
 * Minting: Algorithmic
 * Relative stability: pegged to USD
 */

contract MockMintingFail is ERC20Burnable, Ownable {
    /**
     * Errors
     */
    error DecentralizedStableCoin__buriningAmountMustBeGreaterThenZero();
    error DecentralizedStableCoin__burningAmountExceedsBalance();
    error DecentralizedStableCoin__youCannotMintAtZeroAddress();
    error DecentralizedStableCoin__MintingAmountShouldBeGreaterThanZero();

    constructor() ERC20("hoBabu", "hB") Ownable(msg.sender) {}

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (amount <= 0) {
            revert DecentralizedStableCoin__buriningAmountMustBeGreaterThenZero();
        }
        if (amount > balance) {
            revert DecentralizedStableCoin__burningAmountExceedsBalance();
        }
        /**
         * this keyword (super) says that use the function as it was before after doin this check
         * use the brun function from parent class
         */
        super.burn(amount);
    }

    function mint(address to, uint256 value) external onlyOwner returns (bool) {
        if (to == address(0)) {
            revert DecentralizedStableCoin__youCannotMintAtZeroAddress();
        }
        if (value <= 0) {
            revert DecentralizedStableCoin__MintingAmountShouldBeGreaterThanZero();
        }
        // we are not overrinding so we wont use super keyword
        _mint(to, value);

        return false;
    }
}
