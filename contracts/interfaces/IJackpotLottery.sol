// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

interface IJackpotLottery {
    function revealRandomNumbers(
        uint256 _lotteryId,
        uint256 _requestId,
        uint256 _randomNumber
    ) external;
}
