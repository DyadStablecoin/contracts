// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Licenser} from "./Licenser.sol";

import {Owned}         from "@solmate/src/auth/Owned.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LicenserManager is Owned(msg.sender) {
  using EnumerableSet for EnumerableSet.AddressSet;

  uint public maxVaults = 20;
  Licenser public immutable licenser;
  EnumerableSet.AddressSet private licensedVaults;

  constructor(Licenser _licenser) {
    licenser = _licenser;
  }

  function licenseVault(
      address _vault
  ) external 
      onlyOwner {
    require(licensedVaults.length() < maxVaults);
    require(licensedVaults.add(_vault));
    licenser.add(_vault);
  }

  function unlicenseVault(
      address _vault
  ) external 
      onlyOwner {
    require(licensedVaults.remove(_vault));
    licenser.remove(_vault);
  }

  function increaseMaxVaults(
      uint _maxVaults
  ) external 
      onlyOwner {
    require(_maxVaults > maxVaults);
    maxVaults = _maxVaults;
  }

  function getLicensedVaults() 
    external 
    view 
    returns (address[] memory) {
      address[] memory vaults = new address[](licensedVaults.length());
      for (uint i = 0; i < licensedVaults.length(); i++) {
        vaults[i] = licensedVaults.at(i);
      }
      return vaults;
  }

  function getLicensedVaultsLength() 
    external 
    view 
    returns (uint) {
      return licensedVaults.length();
  }
}
