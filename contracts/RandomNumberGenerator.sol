// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "./interfaces/IJackpotLottery.sol";

contract RandomNumberGenerator is VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface internal COORDINATOR;

    uint64 internal immutable subscriptionId;
    address internal immutable vrfCoordinator;
    bytes32 internal immutable keyHash;
    uint32 internal constant CALLBACK_GAS_LIMIT = 100000;
    uint16 internal constant REQUEST_CONFIRMATIONS = 3;
    uint32 internal constant NUM_WORDS = 1;

    uint256 internal currentLotteryId;
    address internal requester;
    address internal lottery;

    uint256[] internal words;

    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        address _lottery
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        vrfCoordinator = _vrfCoordinator;
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        lottery = _lottery;
    }

    /** MODIFIER */
    modifier onlyLottery() {
        require(msg.sender == lottery, "Not a lottery");
        _;
    }

    /** EXTERNAL FUNCTIONS */
    function requestRandomWords(uint256 _lotteryId) external onlyLottery returns (uint256) {
        requester = msg.sender;
        currentLotteryId = _lotteryId;
        // Will revert if subscription is not set and funded.
        return
            COORDINATOR.requestRandomWords(
                keyHash,
                subscriptionId,
                REQUEST_CONFIRMATIONS,
                CALLBACK_GAS_LIMIT,
                NUM_WORDS
            );
    }

    /** INTERNAL FUNCTIONS */
    function fulfillRandomWords(uint256 requestId, uint256[] memory _randomWords) internal override {
        IJackpotLottery(lottery).revealRandomNumbers(currentLotteryId, requestId, _randomWords[0]);
    }
}
