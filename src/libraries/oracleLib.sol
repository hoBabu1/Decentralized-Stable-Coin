//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/**
 * @title Oracle Lib
 * @author Aman Kumar
 * @notice This library is used to check thr chainlink Oracle for stale data
 * If a price is stale,the function will revert, and render the DSCBrain
 * Freeze if prices become stale
 */

library Oraclelib {
    error Oraclelib__stalePrice();

    uint256 private constant TIMEOUT = 3 hours; // 3*60*60

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) {
            revert Oraclelib__stalePrice();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
