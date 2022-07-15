// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract JackpotLottery {
    using Address for address;

    uint256 public immutable lotteryId;
    IERC20 public immutable token;
    uint256 public immutable ticketPrice;

    constructor(
        uint256 _lotteryId,
        address _token,
        uint256 _ticketPrice
    ) {
        require(_token != address(0), "Invalid token address");

        lotteryId = _lotteryId;
        token = IERC20(_token);
        ticketPrice = _ticketPrice;
    }

    /** MODIFIERS */
    modifier notContract() {
        require(!address(msg.sender).isContract(), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    function buyTicket(uint256 _numOfTickets, uint256[] memory _nums) external notContract {}
}
