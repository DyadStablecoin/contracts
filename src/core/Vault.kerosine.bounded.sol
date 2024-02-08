// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IVault} from "../interfaces/IVault.sol";

contract BoundedKerosineVault is IVault {

  mapping(uint => uint) public id2asset;

  modifier onlyVaultManager() {
    if (msg.sender != address(vaultManager)) revert NotVaultManager();
    _;
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
    external
    view 
    returns (uint) {
      return id2asset[id] * assetPrice() * 2;
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
