// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract RandomNumberGenerator is VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface internal COORDINATOR;

    uint64 internal immutable subscriptionId;
    address internal immutable vrfCoordinator;
    bytes32 internal immutable keyHash;
    uint32 internal constant CALLBACK_GAS_LIMIT = 100000;
    uint16 internal constant REQUEST_CONFIRMATIONS = 3;
    uint32 internal constant NUM_WORDS = 6;

    uint256 public requestId;
    uint256[] internal words;

    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        vrfCoordinator = _vrfCoordinator;
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
    }

    function requestRandomWords() external {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory _randomWords
    ) internal override {
        words = _randomWords;
    }
}
