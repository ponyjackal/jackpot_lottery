// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IJackpotLotteryTicket.sol";

contract JackpotLottery {
    using Address for address;

    uint256 public immutable lotteryId;
    IERC20 public immutable token;
    IJackpotLotteryTicket public immutable ticket;
    uint256 public immutable ticketPrice;
    uint256 public immutable startTime;
    uint256 public immutable lotteryPeriod;

    bool public claimed;
    bytes32 internal requestId;

    enum Status {
        NotStarted,
        Open,
        Closed,
        Completed
    }
    Status public status;
    //TODO; add timestamp
    //TODO; add rewards
    //TODO; update lottery contract from factory module to manage all lotteries

    uint8 public constant SIZE_OF_NUMBER = 6;

    constructor(
        uint256 _lotteryId,
        address _token,
        address _ticket,
        uint256 _ticketPrice,
        uint256 _startTime,
        uint256 _lotteryPeriod
    ) {
        require(_token != address(0), "Invalid token address");

        lotteryId = _lotteryId;
        token = IERC20(_token);
        ticket = IJackpotLotteryTicket(_ticket);
        ticketPrice = _ticketPrice;
        startTime = _startTime;
        lotteryPeriod = _lotteryPeriod;
    }

    /** MODIFIERS */
    modifier notContract() {
        require(!address(msg.sender).isContract(), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    /** EXTERNAL FUNCTIONS */
    function buyTicket(uint8 _numOfTickets, uint16[] memory _nums) external notContract returns (uint256[] memory) {
        //TODO; add more validations
        uint256 numCheck = SIZE_OF_NUMBER * _numOfTickets;
        require(_nums.length == numCheck, "Invalid numbers");

        token.transferFrom(msg.sender, address(this), ticketPrice * _numOfTickets);
        // mint tickets
        uint256[] memory ticketIds = ticket.batchMint(msg.sender, lotteryId, _numOfTickets, _nums);
        return ticketIds;
    }

    function claimRewards(uint256[] calldata _ticketIds) external notContract {
        require(block.timestamp >= startTime + lotteryPeriod, "Lottery is not end yet");
        if (status == Status.Open) {
            _getRandomNumber();
        }
    }

    /** INTERNAL FUNCTIONS */
    function _getRandomNumber() internal {
        require(block.timestamp >= startTime + lotteryPeriod, "Lottery is not end yet");
        require(status == Status.Open, "Lottery is not open");

        status = Status.Closed;
    }
}
