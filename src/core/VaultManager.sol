// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";

import {DNft}          from "./DNft.sol";
import {Dyad}          from "./Dyad.sol";
import {Licenser}      from "./Licenser.sol";
import {Vault}         from "./Vault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";

contract VaultManager is IVaultManager {
  using FixedPointMathLib for uint;

  uint public constant MAX_VAULTS                = 5;
  uint public constant MIN_COLLATERIZATION_RATIO = 15e17; // 150%

  DNft     public immutable dNft;
  Dyad     public immutable dyad;
  Licenser public immutable vaultLicenser;

  mapping (uint => address[])                 public vaults; 
  mapping (uint => mapping (address => bool)) public isDNftVault;

  modifier isDNftOwner(uint id) {
    if (dNft.ownerOf(id) != msg.sender)   revert NotOwner();    _;
  }
  modifier isValidDNft(uint id) {
    if (id >= dNft.totalSupply())         revert InvalidNft();  _;
  }
  modifier isLicensed(address vault) {
    if (!vaultLicenser.isLicensed(vault)) revert NotLicensed(); _;
  }

  constructor(
    DNft     _dNft,
    Dyad     _dyad,
    Licenser _licenser
  ) {
    dNft          = _dNft;
    dyad          = _dyad;
    vaultLicenser = _licenser;
  }

  function add(
      uint    id,
      address vault
  ) 
    external
      isDNftOwner(id)
  {
    if (vaults[id].length >= MAX_VAULTS)  revert TooManyVaults();
    if (!vaultLicenser.isLicensed(vault)) revert VaultNotLicensed();
    if (isDNftVault[id][vault])           revert VaultAlreadyAdded();
    vaults[id].push(vault);
    isDNftVault[id][vault] = true;
    emit Added(id, vault);
  }

  function remove(
      uint    id,
      address vault
  ) 
    external
      isDNftOwner(id)
  {
    if (!isDNftVault[id][vault]) revert NotDNftVault();
    uint numberOfVaults = vaults[id].length;
    uint index; 
    for (uint i = 0; i < numberOfVaults; i++) {
      if (vaults[id][i] == vault) {
        index = i;
        break;
      }
    }
    vaults[id][index] = vaults[id][numberOfVaults - 1];
    vaults[id].pop();
    isDNftVault[id][vault] = false;
    emit Removed(id, vault);
  }

  function deposit(
    uint    id,
    address vault,
    uint    amount
  ) 
    external 
    payable
      isValidDNft(id) 
  {
    Vault _vault = Vault(vault);
    _vault.asset().transferFrom(msg.sender, address(vault), amount);
    _vault.deposit(id, amount);
  }

  function withdraw(
    uint    id,
    address vault,
    uint    amount,
    address to
  ) 
    public 
      isDNftOwner(id)
  {
    Vault(vault).withdraw(id, to, amount);
    if (collatRatio(id) < MIN_COLLATERIZATION_RATIO) revert CrTooLow(); 
  }

  function mintDyad(
    uint    id,
    uint    amount,
    address to
  )
    external 
      isDNftOwner(id)
  {
    dyad.mint(id, to, amount);
    if (collatRatio(id) < MIN_COLLATERIZATION_RATIO) revert CrTooLow(); 
  }

  function burnDyad(
    uint id,
    uint amount
  ) 
    external 
      isValidDNft(id)
  {
    dyad.burn(id, msg.sender, amount);
  }

  function redeemDyad(
    uint    id,
    address vault,
    uint    amount,
    address to
  )
    external 
      isDNftOwner(id)
    returns (uint) { 
      dyad.burn(id, msg.sender, amount);
      Vault _vault = Vault(vault);
      uint asset  = amount * (10**_vault.oracle().decimals()) / _vault.assetPrice();
      withdraw(id, vault, asset, to);
      return asset;
  }

  function liquidate(
    uint id,
    uint to
  ) 
    external 
      isValidDNft(id)
      isValidDNft(to)
    payable {
      if (collatRatio(id) >= MIN_COLLATERIZATION_RATIO) revert CrTooHigh(); 
      uint mintedDyad = dyad.mintedDyad(address(this), id);
      dyad.burn(id, msg.sender, mintedDyad);

      uint numberOfVaults = vaults[id].length;
      for (uint i = 0; i < numberOfVaults; i++) {
        Vault(vaults[id][i]).move(id, to);
      }
  }

  function collatRatio(
    uint id
  )
    public 
    view
    returns (uint) {
      uint _dyad = dyad.mintedDyad(address(this), id);
      if (_dyad == 0) return type(uint).max;
      return getTotalUsdValue(id).divWadDown(_dyad);
  }

  function getTotalUsdValue(
    uint id
  ) 
    public 
    view
    returns (uint) {
      uint totalUsdValue;
      uint numberOfVaults = vaults[id].length; 
      for (uint i = 0; i < numberOfVaults; i++) {
        Vault vault = Vault(vaults[id][i]);
        uint usdValue;
        if (vaultLicenser.isLicensed(address(vault))) {
          usdValue = vault.getUsdValue(id);        
        }
        totalUsdValue += usdValue;
      }
      return totalUsdValue;
  }
}
