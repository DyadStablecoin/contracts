// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {KerosineVault}        from "./Vault.kerosine.sol";
import {VaultManager}         from "./VaultManager.sol";
import {Dyad}                 from "./Dyad.sol";
import {KerosineManager}      from "./KerosineManager.sol";
import {BoundedKerosineVault} from "./Vault.kerosine.bounded.sol";

import {ERC20}           from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

contract UnboundedKerosineVault is KerosineVault {
  using SafeTransferLib for ERC20;

  BoundedKerosineVault public boundedKerosineVault;

  constructor(
    VaultManager    _vaultManager,
    ERC20           _asset, 
    Dyad            _dyad, 
    KerosineManager _kerosineManager
  ) KerosineVault(_vaultManager, _asset, _dyad, _kerosineManager) {}

  function setBoundedKerosineVault(
    BoundedKerosineVault _boundedKerosineVault
  )
    external
    onlyOwner
  {
    boundedKerosineVault = _boundedKerosineVault;
  }

  function withdraw(
    uint    id,
    address to,
    uint    amount
  ) 
    external 
      onlyVaultManager
  {
    id2asset[id]       -= amount;
    totalDepositAmount -= amount;
    asset.safeTransfer(to, amount); 
    emit Withdraw(id, to, amount);
  }

  function getTotalKerosine()
    public
    override
    view
    returns (uint) {
      return 
        totalDepositAmount 
      - boundedKerosineVault.totalDepositAmount();
  }
}
