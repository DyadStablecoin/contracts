// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

contract OracleMock {
  int public price = 1000e8; // ETH/USD

  function setPrice(int _price) external {
    price = _price;
  }

  function latestRoundData() public view returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
  ) {
      return (1, price, 1, 1, 1);  
  }

  function decimals() public pure returns (uint8) {
    return 8;
  }
}
