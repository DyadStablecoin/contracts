// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {DNft}          from "./DNft.sol";
import {Dyad}          from "./Dyad.sol";
import {Licenser}      from "./Licenser.sol";
import {Vault}         from "./Vault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";

contract VaultManager is IVaultManager {
  using FixedPointMathLib for uint;

  uint public constant MAX_VAULTS = 5;
  uint public constant MIN_COLLATERIZATION_RATIO = 15e17; // 150%

  DNft     public immutable dNft;
  Dyad     public immutable dyad;
  Licenser public immutable licenser;

  mapping (uint => address[])                 public vaults; 
  mapping (uint => mapping (address => bool)) public isDNftVault;

  modifier isDNftOwner(uint id) {
    if (dNft.ownerOf(id) != msg.sender) revert NotOwner(); _;
  }
  modifier isValidDNft(uint id) {
    if (id >= dNft.totalSupply()) revert InvalidNft(); _;
  }
  modifier isLicensed(address vault) {
    if (!licenser.isLicensed(vault)) revert NotLicensed(); _;
  }

  constructor(
    DNft     _dNft,
    Dyad     _dyad,
    Licenser _licenser
  ) {
    dNft     = _dNft;
    dyad     = _dyad;
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

  function deposit(uint id, address vault, uint amount) 
  external 
  payable
    isValidDNft(id) 
    isLicensed(vault)
  {
    Vault(vault).deposit(id, amount);
  }

  function withdraw(uint id, address vault, address to, uint amount) 
  external 
    isDNftOwner(id)
  {
    Vault(vault).withdraw(id, to, amount);
    if (collatRatio(id) < MIN_COLLATERIZATION_RATIO) revert CrTooLow(); 
  }

  function collatRatio(uint id)
  public 
  view
  returns (uint) {
    uint totalUsdValue = getTotalUsdValue(id);
    uint _dyad = dyad.mintedDyad(address(this), id);
    if (_dyad == 0) return type(uint).max;
    return totalUsdValue.divWadDown(_dyad);
  }

  function getTotalUsdValue(uint id) 
  public 
  view
  returns (uint) {
    uint totalUsdValue;
    uint numberOfVaults = vaults[id].length; 
    for (uint i = 0; i < numberOfVaults; i++) {
      Vault vault = Vault(vaults[id][i]);
      uint usdValue;
      if (licenser.isLicensed(address(vault))) {
        usdValue = vault.id2asset(id) 
                    * vault.assetPrice() 
                    / (10**vault.oracle().decimals());
      }
      totalUsdValue += usdValue;
    }
    return totalUsdValue;
  }
}
