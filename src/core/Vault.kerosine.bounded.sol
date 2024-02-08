// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {KerosineVault}   from "./Vault.kerosine.sol";
import {VaultManager}    from "./VaultManager.sol";
import {Dyad}            from "./Dyad.sol";
import {KerosineManager} from "./KerosineManager.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract BoundedKerosineVault is KerosineVault {

  constructor(
    VaultManager    _vaultManager,
    ERC20           _asset, 
    Dyad            _dyad, 
    KerosineManager _kerosineManager
  ) KerosineVault(_vaultManager, _asset, _dyad, _kerosineManager) {}

  function getUsdValue(
    uint id
  )
    public
    override
    view 
    returns (uint) {
      return super.getUsdValue(id) * 2;
  }
}
