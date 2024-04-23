// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IAggregatorV3} from "../interfaces/IAggregatorV3.sol";

contract KeroseneOracle is IAggregatorV3 {
  function decimals() external pure returns (uint8) { return 18; }
  function description() external pure override returns (string memory) { return "Kerosene Oracle"; }
  function version() external pure override returns (uint256) { return 1; }
  function getRoundData(uint80 _roundId) external pure override returns (uint80, int256, uint256, uint256, uint80) { return (_roundId, 0, 0, 0, 0); }
  function latestRoundData() external pure override returns (uint80, int256, uint256, uint256, uint80) { return (0, 0, 0, 0, 0); }
}
