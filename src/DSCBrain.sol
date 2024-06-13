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
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
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
    error DSCBrain__TransferOfTokenFailedFromUserToContract();
    error DSCBrain__HealthFactorIsBroken(uint256 healthFactor);
    error DSCBrain__MintFailed();
    ///////////////////////
    // StateVarialble ////
    //////////////////////
    uint256 private constant ADDRESS_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESOLD = 50 ;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeed; // token to priceFeed
    mapping(address user => mapping(address token => uint256 value)) private s_colletralDeposited;
    mapping(address user => uint256 amountOfDSc) private s_amountOfDscMinted;
    DecentralizedStableCoin private immutable i_dsc;
    address[] private s_colletralToken;


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
            s_colletralToken.push(tokenAddress[i]);
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
        s_colletralDeposited[msg.sender][tokenColletral] += amount;
        emit tokenDepositedSuccessFully(tokenColletral, amount);
        bool success = IERC20(tokenColletral).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert DSCBrain__TransferOfTokenFailedFromUserToContract();
        }
    }
    /**
     * @param amountOfDSCtoMint - Amount of DSC user to mint
     * @notice - user must have enough colletral to mint DSC token
     */

    function mintDSC(uint256 amountOfDSCtoMint) external moreThenZero(amountOfDSCtoMint) {
        s_amountOfDscMinted[msg.sender] += amountOfDSCtoMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender,amountOfDSCtoMint);
        if(!minted)
        {
            revert DSCBrain__MintFailed();

        }
    }

    function redeemColletralForDSC() external {}
    function liquidate() external {}
    function getHealthFactor() external view {}

    /////////////////////////////////////////
    /// Internal and Private function ///////
    /////////////////////////////////////////

    /**
     * @param user - user address
     * Returns how lose to liquidation a user is
     * If a user goes below 1, they can get liquidate
     */
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted
        // total colletral value
        (uint256 totalDscMinted, uint256 totalValueInUsd) = _getAccountInfoOfUser(user);
        uint256 colletralAdjustedForTHresold = (totalValueInUsd * LIQUIDATION_THRESOLD ) /LIQUIDATION_PRECISION;
        return (colletralAdjustedForTHresold * PRECISION)/totalDscMinted;
    }

    function _getAccountInfoOfUser(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 totalValueInUsd)
    {
        totalDscMinted = s_amountOfDscMinted[user];
        totalValueInUsd = getAccountColletralValue(user);
        
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // check do they have enough colletral
        // revert if they dont have
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR)
        {
            revert DSCBrain__HealthFactorIsBroken(userHealthFactor);
        }
    
    }
    //////////////////////////////////////////////
    /// Public and external view  function ///////
    //////////////////////////////////////////////

    function getAccountColletralValue(address user) public view returns (uint256 totalColletralValueInUsd) {
        // loop through all the address -- get price of each and add it
        for (uint256 i = 0; i < s_colletralToken.length; i++) {
            address token = s_colletralToken[i];
            uint256 amount = s_colletralDeposited[user][token];
            getValueInUSD(token, amount);
            totalColletralValueInUsd+=getValueInUSD(token,amount);
        }
    }
    function getValueInUSD(address token, uint256 amount) public view returns (uint256) {
        (, int256 price,,,) = AggregatorV3Interface(s_priceFeed[token]).latestRoundData();
          return (uint256(price) * ADDRESS_FEED_PRECISION) * amount / PRECISION;
    }
}
