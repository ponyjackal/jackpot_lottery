// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IJackpotLotteryTicket.sol";
import "./interfaces/IChainlinkAggregator.sol";

contract JackpotLottery is Ownable {
    using Address for address;

    IJackpotLotteryTicket internal ticket;
    IChainlinkAggregator internal chainlinkAggregator;
    IERC20 public myToken;

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
    bytes32 internal priceRequestId;

    struct LotteryInfo {
        uint256 lotteryId;
        // token info
        address token;
        uint256 tokenPrice;
        uint256 priceLastUpdatedTime;
        string tokenId;
        Status status;
        uint256 ticketPrice; // USD
        uint256 startTime;
        uint256 endTime;
        uint16[] winningNumbers;
    }

    // id => LotteryInfo mapping
    mapping(uint256 => LotteryInfo) internal lotteries;

    uint256 public constant PRICE = 1 ether;
    uint256 public constant TICKET_SALE_END_DUE = 30 minutes;
    uint8 public constant SIZE_OF_NUMBER = 6;
    // How long will the contract assume rate update is not needed
    uint256 public constant rateFreshPeriod = 1 hours;

    //-------------------------------------------------------------------------
    // EVENTS
    //-------------------------------------------------------------------------

    event TicketUpdated(address ticket);
    event TokenUpdated(address token);
    event ChainlinkAggregatorUpdated(address chainlinkAggregator);

    event NewLotteryCreate(
        uint256 indexed lotteryId,
        address indexed owner,
        address token,
        uint256 ticketPrice,
        uint256 startTime,
        uint256 endTime
    );
    event TicketBought(uint256 indexed lotteryId, address indexed owner, uint8 indexed buyType, uint8 numberOfTickets);
    event TicketsClaimed(uint256 indexed lotteryId, uint256[] ticketIds);

    event WinningNumberRevealed(uint256 indexed lotteryId, uint16[] winningNumbers);

    /** CONSTRUCTOR */
    constructor(
        address _token,
        address _ticket,
        address _chainlinkAggregator
    ) {
        require(_token != address(0), "Invalid token address");
        require(_ticket != address(0), "Invalid ticket address");
        require(_chainlinkAggregator != address(0), "Invalid chainlinkAggregator address");

        myToken = IERC20(_token);
        ticket = IJackpotLotteryTicket(_ticket);
        chainlinkAggregator = IChainlinkAggregator(_chainlinkAggregator);
    }

    /** MODIFIERS */
    modifier notContract() {
        require(!address(msg.sender).isContract(), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    modifier onlyChainlinkAggregator() {
        require(msg.sender == address(chainlinkAggregator), "Not a chainlinkAggregator");
        _;
    }

    /** SETTER FUNCTIONS */
    /**
     * @dev update ticket contract
     * @param _ticket new ticket address
     */
    function setTicket(address _ticket) external onlyOwner {
        require(_ticket != address(0), "Invalid ticket address");
        ticket = IJackpotLotteryTicket(_ticket);
        emit TicketUpdated(_ticket);
    }

    /**
     * @dev update token contract
     * @param _token new token address
     */
    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid ticket address");
        myToken = IERC20(_token);
        emit TokenUpdated(_token);
    }

    /**
     * @dev update chainlinkAggregator contract
     * @param _chainlinkAggregator new chainlinkAggregator address
     */
    function setChainlinkAggregator(address _chainlinkAggregator) external onlyOwner {
        require(_chainlinkAggregator != address(0), "Invalid ticket address");
        chainlinkAggregator = IChainlinkAggregator(_chainlinkAggregator);
        emit ChainlinkAggregatorUpdated(_chainlinkAggregator);
    }

    /** EXTERNAL FUNCTIONS */
    /**
     * @dev create a new lottery, users need to pay 1 BNB
     * @param _token partner token address
     * @param _tokenId partner tokenId on coingecko
     * @param _ticketPrice ticket price in usd
     * @param _startTime lottery start time
     * @param _endTime lottery end time
     */
    function creatLottery(
        address _token,
        string memory _tokenId,
        uint256 _ticketPrice,
        uint256 _startTime,
        uint256 _endTime
    ) external payable notContract {
        require(_token != address(0), "Invalid token address");
        require(msg.value >= PRICE, "Insufficient fee");
        require(_startTime < _endTime, "Invalid start and end time");

        // refund
        refundIfOver(PRICE);

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
            0,
            0,
            _tokenId,
            Status.Open,
            _ticketPrice,
            _startTime,
            _endTime,
            winningNumbers
        );
        // request token price update
        priceRequestId = chainlinkAggregator.requestCryptoPrice(_tokenId);
        lotteries[lotteryId] = lottery;
        index++;

        emit NewLotteryCreate(lotteryId, msg.sender, _token, _ticketPrice, _startTime, _endTime);
    }

    /**
     * @dev batch buy a ticket with BNB
     * @param _lotteryId lottery id to buy
     * @param _numOfTickets number of tickets to buy
     * @param _nums numbers user put in the tickets
     */
    function buyTicketWithBNB(
        uint256 _lotteryId,
        uint8 _numOfTickets,
        uint16[] memory _nums
    ) external payable notContract {
        buyTicketValidation(_lotteryId, _numOfTickets, _nums);

        LotteryInfo memory lottery = lotteries[_lotteryId];
        // calculate BNB amount
        (uint256 reserve0, uint256 reserve1) = chainlinkAggregator.getBNBPrice();
        uint256 amount = (lottery.ticketPrice * reserve0 * 10**18) / reserve1;
        require(msg.value >= amount * _numOfTickets, "Insufficient amount");
        // refund
        refundIfOver(amount * _numOfTickets);
        // mint tickets
        ticket.batchMint(msg.sender, lottery.lotteryId, _numOfTickets, _nums);

        emit TicketBought(_lotteryId, msg.sender, 0, _numOfTickets);
    }

    /**
     * @dev batch buy a ticket with partner token
     * @param _lotteryId lottery id to buy
     * @param _numOfTickets number of tickets to buy
     * @param _nums numbers user put in the tickets
     */
    function buyTicketWithPartnerToken(
        uint256 _lotteryId,
        uint8 _numOfTickets,
        uint16[] memory _nums
    ) external notContract {
        buyTicketValidation(_lotteryId, _numOfTickets, _nums);

        LotteryInfo memory lottery = lotteries[_lotteryId];

        IERC20 token = IERC20(lottery.token);
        token.transferFrom(msg.sender, address(this), lottery.ticketPrice * _numOfTickets);
        // mint tickets
        ticket.batchMint(msg.sender, lottery.lotteryId, _numOfTickets, _nums);

        emit TicketBought(_lotteryId, msg.sender, 2, _numOfTickets);
    }

    /**
     * @dev users claim rewards for their ticket
     * @param _lotteryId lottery id to claim
     * @param _ticketIds ticket ids to claim
     */
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

        emit TicketsClaimed(_lotteryId, _ticketIds);
    }

    /** CALLBACK FUNCTIONS */
    /**
     * @dev chainlinkAggregator callback function to reveal random number
     * @param _lotteryId lottery id
     * @param _requestId chainlink request id
     * @param _randomNumber random number
     */
    function revealRandomNumbers(
        uint256 _lotteryId,
        uint256 _requestId,
        uint256 _randomNumber
    ) external onlyChainlinkAggregator {
        require(lotteries[_lotteryId].status == Status.Closed, "Lottery is not closed");
        require(requestId == _requestId, "Invalid request");

        lotteries[_lotteryId].status = Status.Closed;
        lotteries[_lotteryId].winningNumbers = _splitNumber(_randomNumber);
        //TODO; check all tickets and give rewards
        emit WinningNumberRevealed(_lotteryId, lotteries[_lotteryId].winningNumbers);
    }

    /**
     * @dev chainlinkAggregator callback function to update token price
     * @param _requestId chainlink request id
     * @param _lotteryId lottery id
     * @param _price token price
     */
    function updateTokenPrice(
        bytes32 _requestId,
        uint256 _lotteryId,
        uint256 _price
    ) external onlyChainlinkAggregator {
        require(priceRequestId == _requestId, "Invalid request");

        lotteries[_lotteryId].tokenPrice = _price;
        lotteries[_lotteryId].priceLastUpdatedTime = block.timestamp;
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

    function buyTicketValidation(
        uint256 _lotteryId,
        uint8 _numOfTickets,
        uint16[] memory _nums
    ) internal {
        //TODO; add more validations
        require(block.timestamp <= (lotteries[_lotteryId].endTime - TICKET_SALE_END_DUE), "Ticket sale ended");
        uint256 numCheck = SIZE_OF_NUMBER * _numOfTickets;
        require(_nums.length == numCheck, "Invalid numbers");
        // check lottery status
        if (lotteries[_lotteryId].status == Status.NotStarted && lotteries[_lotteryId].startTime >= block.timestamp) {
            lotteries[_lotteryId].status = Status.Open;
        }
        require(lotteries[_lotteryId].status == Status.Open, "Lottery is not started");
    }

    /** PRIVATE FUNCTIONS */
    function refundIfOver(uint256 _price) private {
        require(_price >= 0 && msg.value >= _price, "No need to refund");
        if (msg.value > _price) {
            payable(msg.sender).transfer(msg.value - _price);
        }
    }
}
