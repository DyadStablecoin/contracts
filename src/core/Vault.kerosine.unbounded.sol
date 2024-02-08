// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {KerosineVault} from "./Vault.kerosine.sol";
import {VaultManager}  from "./VaultManager.sol";
import {Dyad}          from "./Dyad.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract UnboundedKerosineVault is KerosineVault {
  constructor(
    VaultManager  _vaultManager,
    ERC20         _asset, 
    Dyad          _dyad
  ) KerosineVault(_vaultManager, _asset, _dyad) {}
}
