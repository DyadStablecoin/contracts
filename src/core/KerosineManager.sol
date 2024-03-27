// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Owned}         from "@solmate/src/auth/Owned.sol";

contract KerosineManager is Owned(msg.sender) {
  error TooManyVaults();

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
    vaults.add(vault);
  }

  function remove(
    address vault
  ) 
    external 
      onlyOwner
  {
    vaults.remove(vault);
  }

  function getVaults() 
    external 
    view 
    returns (address[] memory) {
      return vaults.values();
  }
}
