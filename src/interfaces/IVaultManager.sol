// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;

interface IVaultManager {
  event Added     (uint indexed id, address indexed vault);
  event Removed   (uint indexed id, address indexed vault);
  event MintDyad  (uint indexed id, uint amount, address indexed to);
  event BurnDyad  (uint indexed id, uint amount, address indexed from);
  event RedeemDyad(uint indexed id, address indexed vault, uint amount, address indexed to);
  event Liquidate (uint indexed id, address indexed from, uint indexed to);

  error NotOwner();
  error NotLicensed();
  error OnlyOwner();
  error VaultNotLicensed();
  error TooManyVaults();
  error VaultAlreadyAdded();
  error VaultNotAdded();
  error VaultHasAssets();
  error NotDNftVault();
  error InvalidDNft();
  error CrTooLow();
  error CrTooHigh();
}
