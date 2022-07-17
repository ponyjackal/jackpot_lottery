// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

interface IChainlinkAggregator {
    /**
     * Requests randomness from a user-provided seed
     */
    function requestRandomWords(uint256 lotteryId) external returns (uint256);

    function getBNBPrice() external view returns (uint256, uint256);

    function requestCryptoPrice(string memory tokenId) external returns (bytes32);
}
