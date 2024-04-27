// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Owned} from "@solmate/src/auth/Owned.sol";

contract VaultLicenser is Owned(msg.sender) {
  struct License {
    bool isLicensed;
    bool isKeroseneVault;
  }

  mapping(address => License) public licenses;
  
  function add(
      address _vault,
      bool    _isKeroseneVault
  ) external 
      onlyOwner 
    {
      licenses[_vault] = License(true, _isKeroseneVault);
  }

  function remove(
      address _vault
  ) external 
      onlyOwner 
    {
      licenses[_vault] = License(false, false);
  }

  function isLicensed(
      address _vault
  ) external 
    view 
    returns (bool) 
  {
    return licenses[_vault].isLicensed;
  }

  function isKerosene(
      address _vault
  ) external 
    view 
    returns (bool) 
  {
    return licenses[_vault].isKeroseneVault;
  }
}
