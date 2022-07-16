// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/IJackpotLotteryTicket.sol";
import "./interfaces/IRandomNumberGenerator.sol";

contract JackpotLottery {
    using Address for address;

    IJackpotLotteryTicket internal immutable ticket;
    IRandomNumberGenerator internal immutable randomGenerator;

    enum Status {
        NotStarted,
        Open,
        Closed,
        Completed
    }

    //TODO; add timestamp
    //TODO; add rewards

    uint8 public constant SIZE_OF_NUMBER = 6;
    uint256 public constant PRICE = 1 ether;

    uint256 public index;
    uint256 internal requestId;

    struct LotteryInfo {
        uint256 lotteryId;
        address token;
        Status status;
        uint256 ticketPrice;
        uint256 startTime;
        uint256 lotteryPeriod;
        uint16[] winningNumbers;
    }
    // id => LotteryInfo mapping
    mapping(uint256 => LotteryInfo) internal lotteries;

    constructor(address _ticket, address _randomNumberGenerator) {
        require(_ticket != address(0), "Invalid ticket address");
        require(_randomNumberGenerator != address(0), "Invalid randomNumberGenerator address");

        ticket = IJackpotLotteryTicket(_ticket);
        randomGenerator = IRandomNumberGenerator(_randomNumberGenerator);
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
        uint256 _lotteryPeriod
    ) external payable notContract returns (uint256) {
        require(_token != address(0), "Invalid token address");
        require(msg.value >= PRICE, "Insufficient fee");
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
            _lotteryPeriod,
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
        require(block.timestamp >= lottery.startTime + lottery.lotteryPeriod, "Lottery is not end yet");
        if (lottery.status == Status.Open) {
            lotteries[_lotteryId].status = Status.Closed;
            requestId = randomGenerator.requestRandomWords(lottery.lotteryId);
            //TODO; check matching numbers and give rewards
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
}
