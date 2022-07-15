// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "./JackpotLottery.sol";

contract JackpotLotteryFactory {
    mapping(uint256 => address) public lotteries;
    uint256 public index;

    uint256 public constant PRICE = 1 ether;

    function createLottery(address _token, uint256 _ticketPrice) public payable returns (address) {
        require(_token != address(0), "Invalid token address");
        require(msg.value >= PRICE, "Insufficient fee");

        JackpotLottery lottery = new JackpotLottery(index, _token, _ticketPrice);
        lotteries[index] = address(lottery);
        index++;

        return address(lottery);
    }
}
