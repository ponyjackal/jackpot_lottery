// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

interface IDateTime {
    function isLeapYear(uint16 year) external pure returns (bool);

    function getYear(uint256 timestamp) external pure returns (uint16);

    function getMonth(uint256 timestamp) external pure returns (uint8);

    function getDay(uint256 timestamp) external pure returns (uint8);

    function getHour(uint256 timestamp) external pure returns (uint8);

    function getMinute(uint256 timestamp) external pure returns (uint8);

    function getSecond(uint256 timestamp) external pure returns (uint8);

    function getWeekday(uint256 timestamp) external pure returns (uint8);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day
    ) external pure returns (uint256 timestamp);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 hour
    ) external pure returns (uint256 timestamp);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 hour,
        uint8 minute
    ) external pure returns (uint256 timestamp);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 hour,
        uint8 minute,
        uint8 second
    ) external pure returns (uint256 timestamp);
}
