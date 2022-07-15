// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract JackpotLotteryTicket is ERC1155, Ownable {
    address internal lotteryContract;
    uint256 internal totalSupply;
    uint8 public constant sizeOfNumber = 6;

    struct TicketInfo {
        address owner;
        uint256 lotteryId;
        uint16[] numbers;
        bool claimed;
    }

    mapping(uint256 => TicketInfo) internal ticketInfo;
    mapping(address => mapping(uint256 => uint256[])) internal userTickets;

    constructor(string memory _uri, address _lottery) ERC1155(_uri) {
        require(_lottery != address(0), "Invalid lottery address");

        lotteryContract = _lottery;
    }

    /** MODIFIERS */
    modifier onlyLottery() {
        require(msg.sender == lotteryContract, "Not a lottery");
        _;
    }

    /** VIEW FUNCTIONS */

    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    function getTicketNumer(uint256 _ticketId) external view returns (uint16[] memory) {
        return ticketInfo[_ticketId].numbers;
    }

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

            uint16 start = uint16(i * sizeOfNumber);
            uint16 end = uint16((i + 1) * sizeOfNumber);
            uint16[] calldata numbers = _numbers[start:end];

            ticketInfo[totalSupply] = TicketInfo(_to, _lotteryId, numbers, false);
            userTickets[_to][_lotteryId].push(totalSupply);
        }

        _mintBatch(_to, tokenIds, amounts, msg.data);
        return tokenIds;
    }
}
