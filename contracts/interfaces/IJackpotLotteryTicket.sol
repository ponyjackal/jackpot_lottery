// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

interface IJackpotLotteryTicket {
    struct TicketInfo {
        address owner;
        uint256 lotteryId;
        uint16[] numbers;
        bool claimed;
    }

    /** VIEW FUNCTIONS */
    function getTotalSupply() external view returns (uint256);

    function getTicketNumer(uint256 _ticketId) external view returns (uint16[] memory);

    function getOwnerOfTicket(uint256 _ticketId) external view returns (address);

    function getStatusOfTicket(uint256 _ticketId) external view returns (bool);

    function getTickersOfLottery(uint256 _lotteryId) external view returns (TicketInfo[] memory);

    /** WRITE FUNCTIONS */
    function batchMint(
        address _to,
        uint256 _lotteryId,
        uint8 _quantity,
        uint16[] calldata _numbers
    ) external returns (uint256[] memory);

    function claimTicket(uint256 _tokenId, uint256 _lotteryId) external returns (bool);
}
