// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IDyadXP {
  function updateXP(uint256 noteId) external;
  function beforeKeroseneWithdrawn(uint256 noteId, uint256 amountWithdrawn) external;
  function beforeKeroseneDeposited(uint256 noteId, uint256 amountDeposited) external;
  function afterDyadMinted(uint256 noteId) external;
  function afterDyadBurned(uint256 noteId) external;
  function balanceOfNote(uint256 noteId) external view returns (uint256);
}
