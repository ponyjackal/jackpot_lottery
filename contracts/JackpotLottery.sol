// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/IJackpotLotteryTicket.sol";
import "./interfaces/IRandomNumberGenerator.sol";
import "./interfaces/IDateTime.sol";

contract JackpotLottery {
    using Address for address;

    IJackpotLotteryTicket internal immutable ticket;
    IRandomNumberGenerator internal immutable randomGenerator;
    IDateTime internal immutable dateTime;

    enum Status {
        NotStarted,
        Open,
        Closed,
        Completed
    }

    //TODO; add timestamp
    //TODO; add rewards

    uint256 public index;
    uint256 internal requestId;

    struct LotteryInfo {
        uint256 lotteryId;
        address token;
        Status status;
        uint256 ticketPrice;
        uint256 startTime;
        uint256 endTime;
        uint16[] winningNumbers;
    }

    // id => LotteryInfo mapping
    mapping(uint256 => LotteryInfo) internal lotteries;

    uint256 public constant PRICE = 1 ether;
    uint8 public constant SIZE_OF_NUMBER = 6;
    uint256 public constant TICKET_SALE_END_DUE = 30 minutes;

    uint8 public constant WED_DAY = 2;
    uint8 public constant SAT_DAY = 5;
    uint8 public constant LOTTERY_START_TIME_HOUR = 21;
    uint8 public constant LOTTERY_START_TIME_MIN = 0;
    uint8 public constant TICKET_SALE_END_HOUR = 20;
    uint8 public constant TICKET_SALE_END_MIN = 30;

    constructor(
        address _ticket,
        address _randomNumberGenerator,
        address _dateTime
    ) {
        require(_ticket != address(0), "Invalid ticket address");
        require(_randomNumberGenerator != address(0), "Invalid randomNumberGenerator address");
        require(_dateTime != address(0), "Invalid dateTime address");

        ticket = IJackpotLotteryTicket(_ticket);
        randomGenerator = IRandomNumberGenerator(_randomNumberGenerator);
        dateTime = IDateTime(_dateTime);
    }

    /** MODIFIERS */
    modifier notContract() {
        require(!address(msg.sender).isContract(), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    modifier onlyRandomGenerator() {
        require(msg.sender == address(randomGenerator), "Not a randomGenerator");
        _;
    }

    /** EXTERNAL FUNCTIONS */
    function creatLottery(
        address _token,
        uint256 _ticketPrice,
        uint256 _startTime,
        uint256 _endTime
    ) external payable notContract returns (uint256) {
        require(_token != address(0), "Invalid token address");
        require(msg.value >= PRICE, "Insufficient fee");
        require(_startTime < _endTime, "Invalid start and end time");
        //TODO; refund

        uint256 lotteryId = index;
        Status lotteryStatus;
        if (_startTime >= block.timestamp) {
            lotteryStatus = Status.Open;
        } else {
            lotteryStatus = Status.NotStarted;
        }
        uint16[] memory winningNumbers = new uint16[](SIZE_OF_NUMBER);
        LotteryInfo memory lottery = LotteryInfo(
            lotteryId,
            _token,
            Status.Open,
            _ticketPrice,
            _startTime,
            _endTime,
            winningNumbers
        );
        lotteries[lotteryId] = lottery;
        index++;

        return lotteryId;
    }

    function buyTicket(
        uint256 _lotteryId,
        uint8 _numOfTickets,
        uint16[] memory _nums
    ) external notContract returns (uint256[] memory) {
        //TODO; add more validations
        uint8 weekDay = dateTime.getWeekday(block.timestamp);
        require(block.timestamp <= (lotteries[_lotteryId].endTime - TICKET_SALE_END_DUE), "Ticket sale ended");
        uint256 numCheck = SIZE_OF_NUMBER * _numOfTickets;
        require(_nums.length == numCheck, "Invalid numbers");
        // check lottery status
        if (lotteries[_lotteryId].status == Status.NotStarted && lotteries[_lotteryId].startTime >= block.timestamp) {
            lotteries[_lotteryId].status = Status.Open;
        }
        LotteryInfo memory lottery = lotteries[_lotteryId];
        require(lottery.status == Status.Open, "Lottery is not started");

        IERC20 token = IERC20(lottery.token);
        token.transferFrom(msg.sender, address(this), lottery.ticketPrice * _numOfTickets);
        // mint tickets
        uint256[] memory ticketIds = ticket.batchMint(msg.sender, lottery.lotteryId, _numOfTickets, _nums);
        return ticketIds;
    }

    function claimRewards(uint256 _lotteryId, uint256[] calldata _ticketIds) external notContract {
        LotteryInfo memory lottery = lotteries[_lotteryId];
        require(block.timestamp >= lottery.endTime, "Lottery is not end yet");
        require(lottery.status == Status.Completed, "Winning numbers are not revealed yet");

        for (uint256 i = 0; i < _ticketIds.length; i++) {
            require(ticket.getOwnerOfTicket(_ticketIds[i]) == msg.sender, "Invalid owner");
            if (!ticket.getStatusOfTicket(_ticketIds[i])) {
                require(ticket.claimTicket(_ticketIds[i], _lotteryId), "Invalid ticket numbers");
                uint8 matches = _findMatches(ticket.getTicketNumer(_ticketIds[i]), lottery.winningNumbers);
                //TODO; give rewards
            }
        }
    }

    function revealRandomNumbers(
        uint256 _lotteryId,
        uint256 _requestId,
        uint256 _randomNumber
    ) external onlyRandomGenerator {
        require(lotteries[_lotteryId].status == Status.Closed, "Lottery is not closed");
        require(requestId == _requestId, "Invalid request");

        lotteries[_lotteryId].status = Status.Closed;
        lotteries[_lotteryId].winningNumbers = _splitNumber(_randomNumber);
    }

    /** INTERNAL FUNCTIONS */
    function _splitNumber(uint256 _randomNumber) internal pure returns (uint16[] memory) {
        uint16[] memory winningNumbers = new uint16[](SIZE_OF_NUMBER);

        for (uint8 i = 0; i < SIZE_OF_NUMBER; i++) {
            bytes32 hashOfRandom = keccak256(abi.encodePacked(_randomNumber, i));
            uint256 numberRepresentation = uint256(hashOfRandom);
            winningNumbers[i] = uint16(numberRepresentation % 10);
        }
        return winningNumbers;
    }

    function _findMatches(uint16[] memory _numbers, uint16[] memory _winningNumbers) internal pure returns (uint8) {
        uint8 numOfMatches;
        for (uint8 i = 0; i < SIZE_OF_NUMBER; i++) {
            if (_numbers[i] == _winningNumbers[i]) {
                numOfMatches++;
            }
        }
        return numOfMatches;
    }
}
