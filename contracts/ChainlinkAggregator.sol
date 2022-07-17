// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "./interfaces/IJackpotLottery.sol";
import "./interfaces/IPancakePair.sol";

contract ChainlinkAggregator is VRFConsumerBaseV2, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    VRFCoordinatorV2Interface internal COORDINATOR;

    uint64 internal immutable subscriptionId;
    address internal immutable vrfCoordinator;
    bytes32 internal immutable keyHash;
    uint32 internal constant CALLBACK_GAS_LIMIT = 100000;
    uint16 internal constant REQUEST_CONFIRMATIONS = 3;
    uint32 internal constant NUM_WORDS = 1;
    // WBNB/BUSD PancakePair
    address private constant pancakePairAddress = 0x1B96B92314C44b159149f7E0303511fB2Fc4774f;
    uint256 private constant ORACLE_PRECISION = 1000000000000000000;
    uint256 private constant ORACLE_PAYMENT = 1 * 10**17; // solium-disable-line zeppelin/no-arithmetic-operations
    // Do not allow the oracle to submit times any further forward into the future than this constant.
    uint256 public constant ORACLE_FUTURE_LIMIT = 10 minutes;

    uint256 internal currentLotteryId;
    address internal requester;
    address internal lottery;
    uint256[] internal words;
    bytes32 public oracleJobId;

    struct Request {
        uint256 timestamp;
        uint256 lotteryId;
        string tokenId;
    }
    // request id => Request info
    mapping(bytes32 => Request) private requests;

    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        address _lottery,
        // Chainlink requirementss
        address _chainlinkToken,
        address _chainlinkOracle,
        string memory _chainlinkJobId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        vrfCoordinator = _vrfCoordinator;
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        lottery = _lottery;
        // Setup Chainlink props
        setChainlinkToken(_chainlinkToken);
        setChainlinkOracle(_chainlinkOracle);
        oracleJobId = stringToBytes32(_chainlinkJobId);
    }

    /** MODIFIER */
    modifier onlyLottery() {
        require(msg.sender == lottery, "Not a lottery");
        _;
    }

    modifier validateTimestamp(bytes32 _requestId) {
        require(requests[_requestId].timestamp > block.timestamp - ORACLE_FUTURE_LIMIT, "Request has expired");
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

    /**
     * @dev return BNB price in USD
     */
    function getBNBPrice() external view onlyLottery returns (uint256, uint256) {
        (uint256 reserve0, uint256 reserve1, ) = IPancakePair(pancakePairAddress).getReserves();
        return (reserve0, reserve1);
    }

    /**
     * @notice Initiatiate a price request via chainlink. Provide both the
     * @param tokenId congecko token id
     */
    function requestCryptoPrice(uint256 lotteryId, string memory tokenId) external onlyLottery returns (bytes32) {
        Chainlink.Request memory req = buildChainlinkRequest(oracleJobId, address(this), this.fulfill.selector);
        string memory requestURL = string(
            abi.encodePacked("https://api.coingecko.com/api/v3/simple/price?ids=", tokenId, "&vs_currencies=usd")
        );
        req.add("get", requestURL);

        string memory path = string(abi.encodePacked(tokenId, ".usd"));
        req.add("path", path);

        req.addInt("times", int256(ORACLE_PRECISION));

        bytes32 requestId = sendChainlinkRequest(req, ORACLE_PAYMENT);
        requests[requestId] = Request(block.timestamp, lotteryId, tokenId);

        return requestId;
    }

    /** CALLBACK FUNCTIONS */
    function fulfillRandomWords(uint256 requestId, uint256[] memory _randomWords) internal override {
        IJackpotLottery(lottery).revealRandomNumbers(currentLotteryId, requestId, _randomWords[0]);
    }

    function fulfill(bytes32 _requestId, uint256 _price)
        public
        validateTimestamp(_requestId)
        recordChainlinkFulfillment(_requestId)
    {
        IJackpotLottery(lottery).updateTokenPrice(_requestId, requests[_requestId].lotteryId, _price);

        delete requests[_requestId];
    }

    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            // solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }
}
