// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract JackpotLotteryTicket is ERC1155, Ownable {
    address internal lotteryContract;
    uint256 internal totalSupply;
    uint8 public constant SIZE_OF_NUMBER = 6;

    struct TicketInfo {
        address owner;
        uint256 lotteryId;
        uint16[] numbers;
        bool claimed;
    }
    // token id => ticket info
    mapping(uint256 => TicketInfo) internal ticketInfo;
    // lottery id => TicketInfo
    mapping(uint256 => TicketInfo[]) internal lotteryTickets;
    // lottery id => number of winners
    mapping(uint256 => uint256[]) internal winners;

    //-------------------------------------------------------------------------
    // EVENTS
    //-------------------------------------------------------------------------
    event LotteryUpdated(address lottery);
    event TicketsMinted(address indexed receiver, uint256 indexed lotteryId, uint8 quantity);
    event TicketClaimed(uint256 indexed ticketId, uint256 indexed lotteryId);

    constructor(string memory _uri, address _lottery) ERC1155(_uri) {
        require(_lottery != address(0), "Invalid lottery address");
        lotteryContract = _lottery;
    }

    /** MODIFIERS */
    modifier onlyLottery() {
        require(msg.sender == lotteryContract, "Not a lottery");
        _;
    }

    /** SETTER FUNCTIONS */
    /**
     * @dev update lottery contract
     * @param _lottery new lottery address
     */
    function setLottery(address _lottery) external onlyOwner {
        require(_lottery != address(0), "Invalid lottery address");
        lotteryContract = _lottery;
        emit LotteryUpdated(_lottery);
    }

    /** VIEW FUNCTIONS */

    function getTotalSupply() external view onlyLottery returns (uint256) {
        return totalSupply;
    }

    function getTicketNumer(uint256 _ticketId) external view onlyLottery returns (uint16[] memory) {
        return ticketInfo[_ticketId].numbers;
    }

    function getOwnerOfTicket(uint256 _ticketId) external view onlyLottery returns (address) {
        return ticketInfo[_ticketId].owner;
    }

    function getStatusOfTicket(uint256 _ticketId) external view onlyLottery returns (bool) {
        return ticketInfo[_ticketId].claimed;
    }

    function getNumOfWinners(uint256 _lotteryId) external view onlyLottery returns (uint256[] memory) {
        return winners[_lotteryId];
    }

    /** EXTERNAL FUNCTIONS */
    /**
     * @dev batch mint tickets, only lottery contract can call this
     * @param _to receiver address
     * @param _lotteryId lottery id
     * @param _quantity amount of tickets to mint
     * @param _numbers numbers in the tickets
     */
    function batchMint(
        address _to,
        uint256 _lotteryId,
        uint8 _quantity,
        uint16[] calldata _numbers
    ) external onlyLottery returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](_quantity);
        uint256[] memory amounts = new uint256[](_quantity);

        for (uint8 i = 0; i < _quantity; i++) {
            totalSupply++;
            tokenIds[i] = totalSupply;
            amounts[i] = 1;

            uint16 start = uint16(i * SIZE_OF_NUMBER);
            uint16 end = uint16((i + 1) * SIZE_OF_NUMBER);
            uint16[] calldata numbers = _numbers[start:end];

            TicketInfo memory ticket = TicketInfo(_to, _lotteryId, numbers, false);
            ticketInfo[totalSupply] = ticket;
            lotteryTickets[_lotteryId].push(ticket);
        }

        _mintBatch(_to, tokenIds, amounts, msg.data);
        emit TicketsMinted(_to, _lotteryId, _quantity);
        return tokenIds;
    }

    /**
     * @dev claim a ticket, only lottery contract can call this
     * @param _ticketId ticket id
     * @param _lotteryId lottery id
     */
    function claimTicket(uint256 _ticketId, uint256 _lotteryId) external onlyLottery returns (bool) {
        require(!ticketInfo[_ticketId].claimed, "Ticket already claimed");
        require(ticketInfo[_ticketId].lotteryId == _lotteryId, "Invalid lottery id");

        for (uint8 i = 0; i < SIZE_OF_NUMBER; i++) {
            if (ticketInfo[_ticketId].numbers[i] >= 10) {
                return false;
            }
        }

        ticketInfo[_ticketId].claimed = true;
        emit TicketClaimed(_ticketId, _lotteryId);
        return true;
    }

    /**
     * @dev count winners by its matching numbers, called by lottery
     * @param _lotteryId lottery id
     * @param _winningNumbers winning numbers
     */
    function countWinners(uint256 _lotteryId, uint16[] memory _winningNumbers) external onlyLottery {
        for (uint256 i = 0; i < lotteryTickets[_lotteryId].length; i++) {
            TicketInfo memory ticket = lotteryTickets[_lotteryId][i];
            uint8 numOfMatches;
            for (uint8 j = 0; j < SIZE_OF_NUMBER; j++) {
                if (ticket.numbers[j] == _winningNumbers[j]) {
                    numOfMatches++;
                }
            }
            if (numOfMatches > 1) {
                winners[_lotteryId][numOfMatches - 2]++;
            }
        }
    }
}
