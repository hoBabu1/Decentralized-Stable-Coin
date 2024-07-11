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
    error DSCBrain__transferredFailed();
    error DSCBrain__HealthFactorIsOk();
    error DSCBrain__HealthFactorNotImproved();

    ///////////////////////
    // StateVarialble ////
    //////////////////////

    uint256 private constant ADDRESS_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) private s_priceFeed; // token to priceFeed
    mapping(address user => mapping(address token => uint256 value)) private s_colletralDeposited;
    mapping(address user => uint256 amountOfDSc) private s_amountOfDscMinted;
    DecentralizedStableCoin private immutable i_dsc;
    address[] private s_colletralToken;

    /////////////////
    // Events //////
    ////////////////

    event tokenDepositedSuccessFully(address indexed tokenAddress, uint256 indexed amount);
    event colletralReedemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed tokenColletralAddress, uint256 amount
    );
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
    /**
     * @param tokenColletral - address of token that user will deposit
     * @param amount - The amount of olletral to deposit
     * @param amountOfDSCtoMint -  Amount of token user to mint
     * @notice Deposit and mint in one call
     */

    function depositColletralAndMintDSC(address tokenColletral, uint256 amount, uint256 amountOfDSCtoMint) external {
        depositColletral(tokenColletral, amount);
        mintDSC(amountOfDSCtoMint);
    }

    /**
     * @param tokenColletral -- address of token that user will deposit
     * @param amount -- The amount of colletral to deposit
     */
    function depositColletral(address tokenColletral, uint256 amount)
        public
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

    function mintDSC(uint256 amountOfDSCtoMint) public moreThenZero(amountOfDSCtoMint) {
        s_amountOfDscMinted[msg.sender] += amountOfDSCtoMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountOfDSCtoMint);
        if (!minted) {
            revert DSCBrain__MintFailed();
        }
    }
    /**
     *
     * @param tokenColletralAddress -- address of token which user wants to redeem
     * @param amountColletral -- amount of colletral user want to reedem
     * @param amountToBurnDsc -- amount of DSC user want to burn
     * This function burns DSC and reedem colletral in one transaction .
     */

    function redeemColletralForDsc(address tokenColletralAddress, uint256 amountColletral, uint256 amountToBurnDsc)
        external
    {
        burnDsc(amountToBurnDsc);
        redeemColletral(tokenColletralAddress, amountColletral);
    }

    function redeemColletral(address tokenColletralAddress, uint256 amountColletral)
        public
        moreThenZero(amountColletral)
        nonReentrant
    {
        _redeemColletral(tokenColletralAddress, amountColletral, address(this), msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(uint256 amount) public moreThenZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
    }
    // If someone is almost uncolletralized, we will pay you to liquidate them

    /**
     * @param colletral - The erc20  colletral to liquidate
     * @param user The user who has broken the health factor , The health factor should be MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC you want to burn to improve the user healh factor
     * @notice - You can partially liquidate a user
     * @notice - you will get a liquidation bonus for taking the user funds
     * @notice - This unction working assumes the protocol will be roughly 200% overcolletralized in order for this to work
     * @notice - A known bug would be if the protocol were 100% or less colletralized, then we wouldnt be able to incentive the liquidator
     * For example - If the price of the colletral plummeted before anyone could be liquidated
     */
    function liquidate(address colletral, address user, uint256 debtToCover)
        external
        moreThenZero(debtToCover)
        nonReentrant
    {
        // check the health factor of the user
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCBrain__HealthFactorIsOk();
        }
        // we want to reduce their dsc debt
        // And take their collateral
        // 140 dollar eth , 100 dsc
        // debt to cover -- 100 dollar
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(colletral, debtToCover);
        // give them 10% bonus
        uint256 bonusColletral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalColletralToReedem = tokenAmountFromDebtCovered + bonusColletral;
        _redeemColletral(colletral, totalColletralToReedem, user, msg.sender);
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor <= endingUserHealthFactor) {
            revert DSCBrain__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /////////////////////////////////////////
    /// Internal and Private function ///////
    /////////////////////////////////////////
    function _redeemColletral(address tokenColletralAddress, uint256 amountColletral, address from, address to)
        private
    {
        s_colletralDeposited[from][tokenColletralAddress] -= amountColletral;
        emit colletralReedemed(from, to, tokenColletralAddress, amountColletral);
        bool success = IERC20(tokenColletralAddress).transfer(to, amountColletral);
        if (!success) {
            revert DSCBrain__transferredFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }
    /**
     * @param user - user address
     * Returns how lose to liquidation a user is
     * If a user goes below 1, they can get liquidate
     */

    function _healthFactor(address user /*private*/ ) public view returns (uint256) {
        (uint256 totalDscMinted, uint256 totalValueInUsd) = _getAccountInfoOfUser(user);
        return _calculateHealthFactor(totalDscMinted, totalValueInUsd);
    }

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 colletralAdjustedForTHresold = (collateralValueInUsd * LIQUIDATION_THRESOLD) / LIQUIDATION_PRECISION;
        return (colletralAdjustedForTHresold * PRECISION) / totalDscMinted;
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
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCBrain__HealthFactorIsBroken(userHealthFactor);
        }
    }
    //////////////////////////////////////////////
    /// Public and external view  function ///////
    //////////////////////////////////////////////
    /**
     *
     * @param amountOfDscToBurn The amount of DSC to Burn
     * @param onBehalfOf -
     * @param dscFrom  -
     *
     * @dev Low-Level internal function, do not call unless the function calling it is checking for health factor being brken
     */

    function _burnDsc(uint256 amountOfDscToBurn, address onBehalfOf, address dscFrom)
        private
        moreThenZero(amountOfDscToBurn)
    {
        s_amountOfDscMinted[onBehalfOf] -= amountOfDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountOfDscToBurn);
        if (!success) {
            revert DSCBrain__transferredFailed();
        }
        i_dsc.burn(amountOfDscToBurn);
    }

    function getTokenAmountFromUsd(address colletral, uint256 usdAmountInWei) public view returns (uint256) {
        // price of eth token
        (, int256 price,,,) = AggregatorV3Interface(s_priceFeed[colletral]).latestRoundData();

        uint256 priceWith18Decimal = uint256(price) * ADDRESS_FEED_PRECISION;
        uint256 amountiInETH = (usdAmountInWei * PRECISION / priceWith18Decimal);
        return amountiInETH;
    }

    function getAccountColletralValue(address user) public view returns (uint256 totalColletralValueInUsd) {
        // loop through all the address -- get price of each and add it
        for (uint256 i = 0; i < s_colletralToken.length; i++) {
            address token = s_colletralToken[i];
            uint256 amount = s_colletralDeposited[user][token];
            getValueInUSD(token, amount);
            totalColletralValueInUsd += getValueInUSD(token, amount);
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    // External & Public View & Pure Functions
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function getValueInUSD(address token, uint256 amount) public view returns (uint256) {
        (, int256 price,,,) = AggregatorV3Interface(s_priceFeed[token]).latestRoundData();
        return (uint256(price) * ADDRESS_FEED_PRECISION) * amount / PRECISION;
    }

    function getColletralDeposited(address user, address token) external view returns (uint256) {
        return s_colletralDeposited[user][token];
    }

    function get_getAccountInfoOfUser(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 totalValueInUsd)
    {
        (totalDscMinted, totalValueInUsd) = _getAccountInfoOfUser(user);
    }

    function getHealthFactor(address user) external view returns (uint256 healthFactor) {
        healthFactor = _healthFactor(user);
    }
    function getAddressFeedPrecision() external pure returns(uint256)
    {
        return ADDRESS_FEED_PRECISION;
    }
    function getPrecision() external pure returns(uint256)
    {
        return PRECISION;
    }
}
