// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;

interface IVaultManager {
  event Added  (uint indexed id, address indexed vault);
  event Removed(uint indexed id, address indexed vault);

  error NotOwner();
  error NotLicensed();
  error OnlyOwner();
  error VaultNotLicensed();
  error TooManyVaults();
  error VaultAlreadyAdded();
  error NotDNftVault();
  error InvalidNft();
  error CrTooLow();
}
