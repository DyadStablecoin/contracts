// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Dyad}                from "./Dyad.sol";
import {Vault}               from "./Vault.sol";
import {KerosineDenominator} from "../staking/KerosineDenominator.sol";
import {IVaultManager}   from "../interfaces/IVaultManager.sol";
import {IVault}          from "../interfaces/IVault.sol";
import {IAggregatorV3}   from "../interfaces/IAggregatorV3.sol";
import {KerosineManager} from "./KerosineManager.sol";

import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";
import {ERC20}           from "@solmate/src/tokens/ERC20.sol";
import {Owned}           from "@solmate/src/auth/Owned.sol";

contract KeroseneVault is IVault, Owned(msg.sender) {
  using SafeTransferLib for ERC20;

  IVaultManager   public immutable vaultManager;
  ERC20           public immutable asset;
  KerosineManager public immutable kerosineManager;
  IAggregatorV3   public immutable oracle;
  Dyad            public immutable dyad;

  KerosineDenominator public kerosineDenominator;

  mapping(uint => uint) public id2asset;

  modifier onlyVaultManager() {
    if (msg.sender != address(vaultManager)) revert NotVaultManager();
    _;
  }

  constructor(
    IVaultManager       _vaultManager,
    ERC20               _asset, 
    Dyad                _dyad,
    KerosineManager     _kerosineManager, 
    IAggregatorV3       _oracle, 
    KerosineDenominator _kerosineDenominator
  ) {
    vaultManager        = _vaultManager;
    asset               = _asset;
    dyad                = _dyad;
    kerosineManager     = _kerosineManager;
    oracle              = _oracle;
    kerosineDenominator = _kerosineDenominator;
  }

  function setDenominator(KerosineDenominator _kerosineDenominator) 
    external 
      onlyOwner
  {
    kerosineDenominator = _kerosineDenominator;
  }

  function deposit(
    uint id,
    uint amount
  )
    public 
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
    view 
    returns (uint) {
      return id2asset[id] * assetPrice() / 1e8;
  }

  function assetPrice() 
    public 
    view 
    override
    returns (uint) {
      uint tvl;
      address[] memory vaults = kerosineManager.getVaults();
      uint numberOfVaults = vaults.length;
      for (uint i = 0; i < numberOfVaults; i++) {
        Vault vault = Vault(vaults[i]);
        tvl += vault.asset().balanceOf(address(vault)) 
                * vault.assetPrice() * 1e18
                / (10**vault.asset().decimals()) 
                / (10**vault.oracle().decimals());
      }
      if (tvl < dyad.totalSupply()) return 0;
      uint numerator   = tvl - dyad.totalSupply();
      uint denominator = kerosineDenominator.denominator();
      return numerator * 1e8 / denominator;
  }
}

