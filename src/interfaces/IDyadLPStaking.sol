// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDyadLPStaking {
    function deposit(uint256 id, uint256 amount) external;
    function withdraw(uint256 id, uint256 amount) external;
}
