// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAggregatorV3} from "../interfaces/IAggregatorV3.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

interface IVault {
    event Withdraw(uint256 indexed from, address indexed to, uint256 amount);
    event Deposit(uint256 indexed id, uint256 amount);
    event Move(uint256 indexed from, uint256 indexed to, uint256 amount);

    error StaleData();
    error IncompleteRound();
    error NotVaultManager();

    // A vault must implement these functions
    function id2asset(uint256) external view returns (uint256);
    function deposit(uint256 id, uint256 amount) external;
    function move(uint256 from, uint256 to, uint256 amount) external;
    function withdraw(uint256 id, address to, uint256 amount) external;
    function getUsdValue(uint256 id) external view returns (uint256);
    function asset() external view returns (ERC20);
    function oracle() external view returns (IAggregatorV3);
    function assetPrice() external view returns (uint256);
}
