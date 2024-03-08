// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {VaultManager}    from "./VaultManager.sol";
import {Dyad}            from "./Dyad.sol";
import {KerosineManager} from "./KerosineManager.sol";
import {IDNft}           from "../interfaces/IDNft.sol";
import {IVault}          from "../interfaces/IVault.sol";

import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";
import {ERC20}           from "@solmate/src/tokens/ERC20.sol";
import {Owned}           from "@solmate/src/auth/Owned.sol";

abstract contract KerosineVault is IVault, Owned(msg.sender) {
  using SafeTransferLib for ERC20;

  VaultManager    public immutable vaultManager;
  ERC20           public immutable asset;
  Dyad            public immutable dyad;
  KerosineManager public immutable kerosineManager;

  mapping(uint => uint) public id2asset;

  modifier onlyVaultManager() {
    if (msg.sender != address(vaultManager)) revert NotVaultManager();
    _;
  }

  constructor(
    VaultManager    _vaultManager,
    ERC20           _asset, 
    Dyad            _dyad,
    KerosineManager _kerosineManager 
  ) {
    vaultManager    = _vaultManager;
    asset           = _asset;
    dyad            = _dyad;
    kerosineManager = _kerosineManager;
  }

  function deposit(
    uint id,
    uint amount
  )
    virtual
    public 
      onlyVaultManager
  {
    id2asset[id] += amount;
    emit Deposit(id, amount);
  }

  function move(
    uint from,
    uint to,
    uint amount
  )
    external
      onlyVaultManager
  {
    id2asset[from] -= amount;
    id2asset[to]   += amount;
    emit Move(from, to, amount);
  }

  function getUsdValue(
    uint id
  )
    public
    view 
    returns (uint) {
      return id2asset[id] * assetPrice();
  }

  function assetPrice() 
    public 
    view 
    virtual
    returns (uint); 
}
