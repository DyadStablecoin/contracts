// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Owned}         from "@solmate/src/auth/Owned.sol";

contract KerosineManager is Owned(msg.sender) {
  error TooManyVaults();
  error VaultAlreadyAdded();
  error VaultNotFound();

  using EnumerableSet for EnumerableSet.AddressSet;

  uint public constant MAX_VAULTS = 10;

  EnumerableSet.AddressSet private vaults;

  function add(
    address vault
  ) 
    external 
      onlyOwner
  {
    if (vaults.length() >= MAX_VAULTS) revert TooManyVaults();
    if (!vaults.add(vault))            revert VaultAlreadyAdded();
  }

  function remove(
    address vault
  ) 
    external 
      onlyOwner
  {
    if (!vaults.remove(vault)) revert VaultNotFound();
  }

  function getVaults() 
    external 
    view 
    returns (address[] memory) {
      return vaults.values();
  }

  function isLicensed(
    address vault
  ) 
    external 
    view 
    returns (bool) {
      return vaults.contains(vault);
  }
}
