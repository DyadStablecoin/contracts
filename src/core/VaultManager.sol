// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {DNft} from "./DNft.sol";
import {Licenser} from "./Licenser.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

contract VaultManager is IVaultManager {

  uint public constant MAX_VAULTS = 5;

  DNft     public immutable dNft;
  Licenser public immutable licenser;

  mapping (uint => address[])                 public vaults; 
  mapping (uint => mapping (address => bool)) public isDNftVault;

  constructor(
    DNft     _dNft,
    Licenser _licenser
  ) {
    dNft     = _dNft;
    licenser = _licenser;
  }

  function add(
      uint    id,
      address vault
  ) external {
      if (dNft.ownerOf(id)  != msg.sender) revert OnlyOwner(); 
      if (vaults[id].length >= MAX_VAULTS) revert TooManyVaults();
      if (!licenser.isLicensed(vault))     revert VaultNotLicensed();
      if (isDNftVault[id][vault])          revert VaultAlreadyAdded();
      vaults[id].push(vault);
      isDNftVault[id][vault] = true;
      emit Added(id, vault);
  }

  function remove(
      uint id,
      uint index
  ) external {
      if (dNft.ownerOf(id) != msg.sender) revert OnlyOwner();
      address vault = vaults[id][index];
      if (!isDNftVault[id][vault])        revert NotDNftVault();
      uint vaultsLength = vaults[id].length;
      vaults[id][index] = vaults[id][vaultsLength - 1];
      vaults[id].pop();
      isDNftVault[id][vault] = false;
      emit Removed(id, vault);
  }
}
