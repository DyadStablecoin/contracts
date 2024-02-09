// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {KerosineVault}          from "./Vault.kerosine.sol";
import {VaultManager}           from "./VaultManager.sol";
import {Dyad}                   from "./Dyad.sol";
import {KerosineManager}        from "./KerosineManager.sol";
import {UnboundedKerosineVault} from "./Vault.kerosine.unbounded.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract BoundedKerosineVault is KerosineVault {
  error NotWithdrawable();

  UnboundedKerosineVault public unboundedKerosineVault;

  constructor(
    VaultManager    _vaultManager,
    ERC20           _asset, 
    Dyad            _dyad, 
    KerosineManager _kerosineManager
  ) KerosineVault(_vaultManager, _asset, _dyad, _kerosineManager) {}

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
  ) external {
    revert NotWithdrawable();
  }

  function getUsdValue(
    uint id
  )
    public
    override
    view 
    returns (uint) {
      return super.getUsdValue(id) * 2;
  }

  function getTotalKerosine()
    public
    override
    view
    returns (uint) {
      return
        asset.balanceOf(address(unboundedKerosineVault)) 
      - asset.balanceOf(address(this));
  }
}
