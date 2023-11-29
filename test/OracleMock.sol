// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

contract OracleMock {
    uint256 public price;

    uint8 public immutable decimals;

    constructor(uint256 _price, uint8 _decimals) {
        price = _price;
        decimals = _decimals;
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function latestRoundData()
        public
        view
        returns (uint80 roundId, uint256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, price, 1, 1, 1);
    }
}
