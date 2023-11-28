// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;

interface IVault {
    event Withdraw(uint256 indexed from, address indexed to, uint256 amount);
    event Deposit(uint256 indexed id, uint256 amount);
    event Move(uint256 indexed from, uint256 indexed to, uint256 amount);

    error StaleData();
    error IncompleteRound();
    error NotVaultManager();
}
