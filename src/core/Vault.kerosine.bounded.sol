// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {KerosineVault}          from "./Vault.kerosine.sol";
import {IVaultManager}          from "../interfaces/IVaultManager.sol";
import {Dyad}                   from "./Dyad.sol";
import {KerosineManager}        from "./KerosineManager.sol";
import {UnboundedKerosineVault} from "./Vault.kerosine.unbounded.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract BoundedKerosineVault is KerosineVault {
  error NotWithdrawable(uint id, address to, uint amount);

  UnboundedKerosineVault public unboundedKerosineVault;

  constructor(
    IVaultManager   _vaultManager,
    ERC20           _asset, 
    KerosineManager _kerosineManager
  ) KerosineVault(_vaultManager, _asset, _kerosineManager) {}

  function setUnboundedKerosineVault(
    UnboundedKerosineVault _unboundedKerosineVault
  )
    external
    onlyOwner
  {
    unboundedKerosineVault = _unboundedKerosineVault;
  }

  function withdraw(
    uint    id,
    address to,
    uint    amount
  ) 
    external 
    view
      onlyVaultManager
  {
    revert NotWithdrawable(id, to, amount);
  }

  function assetPrice() 
    public 
    view 
    override
    returns (uint) {
      return unboundedKerosineVault.assetPrice() * 2;
  }
}
