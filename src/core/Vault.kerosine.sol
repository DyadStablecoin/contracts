// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {VaultManager}  from "./VaultManager.sol";
import {Dyad}          from "./Dyad.sol";
import {Vault}         from "./Vault.sol";
import {IDNft}         from "../interfaces/IDNft.sol";
import {IVault}        from "../interfaces/IVault.sol";

import {EnumerableSet}   from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";
import {ERC20}           from "@solmate/src/tokens/ERC20.sol";
import {Owned}           from "@solmate/src/auth/Owned.sol";

abstract contract KerosineVault is IVault, Owned(msg.sender) {
  using EnumerableSet   for EnumerableSet.AddressSet;
  using SafeTransferLib for ERC20;

  // TODO: add a limit to the number of vaults
  EnumerableSet.AddressSet private vaults;

  VaultManager  public immutable vaultManager;
  ERC20         public immutable asset;
  Dyad          public immutable dyad;

  mapping(uint => uint) public id2asset;

  modifier onlyVaultManager() {
    if (msg.sender != address(vaultManager)) revert NotVaultManager();
    _;
  }

  constructor(
    VaultManager  _vaultManager,
    ERC20         _asset, 
    Dyad          _dyad
  ) {
    vaultManager   = _vaultManager;
    asset          = _asset;
    dyad           = _dyad;
  }

  function addVault(
    address vault
  ) 
    external 
      onlyOwner
  {
    vaults.add(vault);
  }

  function removeVault(
    address vault
  ) 
    external 
      onlyOwner
  {
    vaults.remove(vault);
  }

  function deposit(
    uint id,
    uint amount
  )
    external 
      onlyVaultManager
  {
    id2asset[id] += amount;
    emit Deposit(id, amount);
  }

  function withdraw(
    uint    id,
    address to,
    uint    amount
  ) 
    external 
      onlyVaultManager
  {
    id2asset[id] -= amount;
    asset.safeTransfer(to, amount); 
    emit Withdraw(id, to, amount);
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
    virtual
    view 
    returns (uint) {
      return id2asset[id] * assetPrice();
  }

  function assetPrice() 
    public 
    view 
    returns (uint) {
      uint tvl;
      uint numberOfVaults = vaults.length();
      for (uint i = 0; i < numberOfVaults; i++) {
        Vault vault = Vault(vaults.at(i));
        tvl += vault.asset().balanceOf(address(vault)) * vault.assetPrice();
      }
      return (tvl - dyad.totalSupply()) / asset.totalSupply();
  }
}
