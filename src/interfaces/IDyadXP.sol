// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IDyadXP {
  function updateXP(uint256 noteId) external;
  function beforeKeroseneWithdrawn(uint256 noteId, uint256 amountWithdrawn) external;
}
