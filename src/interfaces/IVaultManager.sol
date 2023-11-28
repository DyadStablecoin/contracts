// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;

interface IVaultManager {
    event Added(uint256 indexed id, address indexed vault);
    event Removed(uint256 indexed id, address indexed vault);
    event MintDyad(uint256 indexed id, uint256 amount, address indexed to);
    event BurnDyad(uint256 indexed id, uint256 amount, address indexed from);
    event RedeemDyad(uint256 indexed id, address indexed vault, uint256 amount, address indexed to);
    event Liquidate(uint256 indexed id, address indexed from, uint256 indexed to);

    error NotOwner();
    error NotLicensed();
    error OnlyOwner();
    error VaultNotLicensed();
    error TooManyVaults();
    error VaultAlreadyAdded();
    error VaultHasAssets();
    error NotDNftVault();
    error InvalidDNft();
    error CrTooLow();
    error CrTooHigh();
}
