//SPDX-License-Identifier:MIT
/**
 * Layout of Contract:
 * version
 * imports
 * interfaces, libraries, contracts
 * errors
 * Type declarations
 * State variables
 * Events
 * Modifiers
 * Functions
 * Layout of Functions:
 * constructor
 * receive function (if exists)
 * fallback function (if exists)
 * external
 * public
 * internal
 * private
 * view & pure functions
 */
pragma solidity ^0.8.0;

import {DecentralizedStableCoin} from "src/decentralizedStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
/**
 * @title DSCBrain
 * @author Aman Kumar
 * THis system is designed to be as minimal as possible, and have the tokens maintain as 1 token == $1 peg
 * This stable coin has the properties
 * -- exogenous Colletral
 * -- Dollar Pegged
 * -- Algorithmically Stable
 *
 * Our DSC system should always be over colletralized.
 * It is similar to DAI had no governance
 * @notice this contract is core of DSC System. It handles all the logic for mining and reedeming DSCas well as depositing and withdrawing colletral.
 * @notice THis contract is very loosely based on MakerDAO DSS System
 */

contract DSCBrain is ReentrancyGuard {
    ///////////////////
    // Errors ////////
    //////////////////

    error DSCBrain__enteredAmountShouldBeMoreThanZero();
    error DSCBrain__thisTokenIsNotAllowed();
    error DSCBrain__ProblemWithTokenAddressAndPriceFeedAddress();

    ///////////////////////
    // StateVarialble ////
    //////////////////////

    mapping(address token => address priceFeed) private s_priceFeed; // token to priceFeed
    mapping(address user => mapping(address token => uint256 value)) private s_colletralDeposited;
    DecentralizedStableCoin private immutable i_dsc;

    /////////////////
    // Events //////
    ////////////////

    event tokenDepositedSuccessFully(address indexed tokenAddress, uint256 indexed amount);
    /////////////////
    // Modifiers ////
    ////////////////

    modifier moreThenZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCBrain__enteredAmountShouldBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_priceFeed[tokenAddress] == address(0)) {
            revert DSCBrain__thisTokenIsNotAllowed();
        }

        _;
    }

    /////////////////
    // Functions ////
    ////////////////
    constructor(address[] memory tokenAddress, address[] memory tokenToPriceFeedAddress, address dscAddress) {
        if (tokenAddress.length != tokenToPriceFeedAddress.length) {
            revert DSCBrain__ProblemWithTokenAddressAndPriceFeedAddress();
        }
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_priceFeed[tokenAddress[i]] = tokenToPriceFeedAddress[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositColletralAndMintDSC() external {}
    /**
     * @param tokenColletral -- address of token that user will deposit
     * @param amount -- The amount of olletral to deposit
     */

    function depositColletral(address tokenColletral, uint256 amount)
        external
        moreThenZero(amount)
        isAllowedToken(tokenColletral)
        nonReentrant
    {
        s_colletralDeposited[msg.sender][tokenColletral] = amount;
        emit tokenDepositedSuccessFully(tokenColletral, amount);
    }

    function mintDSC() external {}
    function redeemColletralForDSC() external {}
    function liquidate() external {}
    function getHealthFactor() external view {}
}
