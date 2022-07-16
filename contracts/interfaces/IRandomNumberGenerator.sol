// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

interface IRandomNumberGenerator {
    /**
     * Requests randomness from a user-provided seed
     */
    function requestRandomWords(uint256 lotteryId) external returns (uint256);
}
