// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DNft}          from "./DNft.sol";
import {Dyad}          from "./Dyad.sol";
import {VaultLicenser} from "./VaultLicenser.sol";
import {Vault}         from "./Vault.sol";
import {DyadXPv2}      from "../staking/DyadXPv2.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {DyadHooks}     from "./DyadHooks.sol";
import "../interfaces/IExtension.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {ERC20}             from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib}   from "@solmate/src/utils/SafeTransferLib.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC1967Proxy}  from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable}    from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:oz-upgrades-from src/core/VaultManagerV3.sol:VaultManagerV3
contract VaultManagerV5 is IVaultManager, UUPSUpgradeable, OwnableUpgradeable {
  using EnumerableSet     for EnumerableSet.AddressSet;
  using FixedPointMathLib for uint;
  using SafeTransferLib   for ERC20;

  uint public constant MAX_VAULTS         = 6;
  uint public constant MIN_COLLAT_RATIO   = 1.5e18; // 150% // Collaterization
  uint public constant LIQUIDATION_REWARD = 0.2e18; //  20%

  address public constant KEROSENE_VAULT = 0x4808e4CC6a2Ba764778A0351E1Be198494aF0b43;

  DNft          public dNft;
  Dyad          public dyad;
  VaultLicenser public vaultLicenser;

  mapping (uint => EnumerableSet.AddressSet) internal vaults; 
  mapping (uint/* id */ => uint/* block */)  private lastDeposit; // not used anymore

  DyadXPv2 public dyadXP;

  // Extensions authorized for use in the system, with bitmap of enabled hooks
  mapping(address => uint256) private _systemExtensions;

  // Extensions authorized by a user for their use
  mapping(address user => EnumerableSet.AddressSet) private _authorizedExtensions;

  modifier isDNftOwner(uint id) {
    if (dNft.ownerOf(id) != msg.sender) revert NotOwner();    _;
  }
  modifier isValidDNft(uint id) {
    if (dNft.ownerOf(id) == address(0)) revert InvalidDNft(); _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() { _disableInitializers(); }

  function initialize()
    public 
      reinitializer(5) 
  {
    // Nothing to initialize right now
  }

  /// @notice Enables a vault for the specified note
  /// @param id The note id
  /// @param vault The vault address
  function add(
      uint    id,
      address vault
  ) 
    external
      isDNftOwner(id)
  {
    if (!vaultLicenser.isLicensed(vault))   revert VaultNotLicensed();
    if ( vaults[id].length() >= MAX_VAULTS) revert TooManyVaults();
    if (!vaults[id].add(vault))             revert VaultAlreadyAdded();
    emit Added(id, vault);
  }

  /// @notice Disables a vault for the specified note. Will fail if the vault has any assets deposited.
  /// @param id The note id
  /// @param vault The vault address
  function remove(
      uint    id,
      address vault
  ) 
    external
      isDNftOwner(id)
  {
    if (Vault(vault).id2asset(id) > 0) revert VaultHasAssets();
    if (!vaults[id].remove(vault))     revert VaultNotAdded();
    emit Removed(id, vault);
  }

  function deposit(
    uint    id,
    address vault,
    uint    amount
  ) 
    external isValidDNft(id)
  {
    uint256 extensionFlags = _systemExtensions[msg.sender];
    Vault _vault = Vault(vault);
    _vault.asset().safeTransferFrom(msg.sender, vault, amount);
    _vault.deposit(id, amount);

    if (vault == KEROSENE_VAULT) {
      dyadXP.afterKeroseneDeposited(id, amount);
    }

    if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.EXTENSION_ENABLED)) {
      if(DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_DEPOSIT)) {
        IAfterDepositHook(msg.sender).afterDeposit(id, vault, amount);
      }
    }
  }

  function withdraw(
    uint    id,
    address vault,
    uint    amount,
    address to
  ) 
    public
  {
    uint256 extensionFlags = _authorizeCall(id);
    if (vault == KEROSENE_VAULT) dyadXP.beforeKeroseneWithdrawn(id, amount);
    Vault(vault).withdraw(id, to, amount); // changes `exo` or `kero` value and `cr`
    if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_WITHDRAW)) {
      IAfterWithdrawHook(msg.sender).afterWithdraw(id, vault, amount, to);
    }
    _checkExoValueAndCollatRatio(id);
  }

  function mintDyad(
    uint    id,
    uint    amount,
    address to
  )
    external 
  {
    uint256 extensionFlags = _authorizeCall(id);
    dyad.mint(id, to, amount); // changes `mintedDyad` and `cr`
    dyadXP.afterDyadMinted(id);
    if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_MINT)) {
      IAfterMintHook(msg.sender).afterMint(id, amount, to);
    }
    _checkExoValueAndCollatRatio(id);
    emit MintDyad(id, amount, to);
  }

  function _checkExoValueAndCollatRatio(
    uint id
  ) 
    internal
    view
  {
    (uint exoValue, uint keroValue) = getVaultsValues(id);
    uint mintedDyad = dyad.mintedDyad(id);
    if (exoValue < mintedDyad) revert NotEnoughExoCollat();
    uint cr = _collatRatio(mintedDyad, exoValue+keroValue);
    if (cr < MIN_COLLAT_RATIO) revert CrTooLow();
  }

  function burnDyad(
    uint id,
    uint amount
  ) 
    public isValidDNft(id)
  {
    uint256 extensionFlags = _systemExtensions[msg.sender];
    dyad.burn(id, msg.sender, amount);
    dyadXP.afterDyadBurned(id);
    if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.EXTENSION_ENABLED)) {
      if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_BURN)) {
        IAfterBurnHook(msg.sender).afterBurn(id, amount);
      }
    }
    emit BurnDyad(id, amount, msg.sender);
  }

  function redeemDyad(
    uint    id,
    address vault,
    uint    amount,
    address to
  )
    external 
    returns (uint) { 
      uint256 extensionFlags = _authorizeCall(id);
      burnDyad(id, amount);
      Vault _vault = Vault(vault);
      uint asset = amount 
                    * (10**(_vault.oracle().decimals() + _vault.asset().decimals())) 
                    / _vault.assetPrice() 
                    / 1e18;
      withdraw(id, vault, asset, to);
      dyadXP.afterDyadBurned(id);

      if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_REDEEM)) {
        IAfterRedeemHook(msg.sender).afterRedeem(id, vault, amount, to, asset);
      }
      emit RedeemDyad(id, vault, amount, to);
      return asset;
  }

  function liquidate(
    uint id,
    uint to,
    uint amount
  ) 
    external 
      isValidDNft(id)
      isValidDNft(to)
    {
      uint cr = collatRatio(id);
      if (cr >= MIN_COLLAT_RATIO) revert CrTooHigh();
      uint debt = dyad.mintedDyad(id);
      dyad.burn(id, msg.sender, amount); // changes `debt` and `cr`

      uint totalValue = getTotalValue(id);
      if (totalValue == 0) return;

      uint numberOfVaults = vaults[id].length();
      for (uint i = 0; i < numberOfVaults; i++) {
        Vault vault = Vault(vaults[id].at(i));
        if (vaultLicenser.isLicensed(address(vault))) {
          uint256 depositAmount = vault.id2asset(id);
          if (depositAmount == 0) continue;
          uint value = vault.getUsdValue(id);
          uint asset;
          if (cr < LIQUIDATION_REWARD + 1e18 && debt != amount) {
            uint cappedCr               = cr < 1e18 ? 1e18 : cr;
            uint liquidationEquityShare = (cappedCr - 1e18).mulWadDown(LIQUIDATION_REWARD);
            uint liquidationAssetShare  = (liquidationEquityShare + 1e18).divWadDown(cappedCr);
            uint allAsset = depositAmount.mulWadUp(liquidationAssetShare);
            asset = allAsset.mulWadDown(amount).divWadDown(debt);
          } else {
            uint share       = value.divWadDown(totalValue);
            uint amountShare = share.mulWadUp(amount);
            uint reward_rate = amount
                                .divWadDown(debt)
                                .mulWadDown(LIQUIDATION_REWARD);
            uint valueToMove = amountShare + amountShare.mulWadUp(reward_rate);
            uint cappedValue = valueToMove > value ? value : valueToMove;
            asset = cappedValue 
                      * (10**(vault.oracle().decimals() + vault.asset().decimals())) 
                      / vault.assetPrice() 
                      / 1e18;
          }
          if (address(vault) == KEROSENE_VAULT) {
            dyadXP.beforeKeroseneWithdrawn(id, asset);
          }
          vault.move(id, to, asset);
          if (address(vault) == KEROSENE_VAULT) {
            dyadXP.afterKeroseneDeposited(to, asset);
          } 
        }
      }

      dyadXP.afterDyadBurned(id);
      emit Liquidate(id, msg.sender, to);
  }

  function collatRatio(
    uint id
  )
    public 
    view
    returns (uint) {
      uint mintedDyad = dyad.mintedDyad(id);
      uint totalValue = getTotalValue(id);
      return _collatRatio(mintedDyad, totalValue);
  }

  /// @dev Why do we have the same function with different arguments?
  ///      Sometimes we can re-use the `mintedDyad` and `totalValue` values,
  ///      Calculating them is expensive, so we can re-use the cached values.
  function _collatRatio(
    uint mintedDyad, 
    uint totalValue // in USD
  )
    internal 
    pure
    returns (uint) {
      if (mintedDyad == 0) return type(uint).max;
      return totalValue.divWadDown(mintedDyad);
  }

  function getTotalValue( // in USD
    uint id
  ) 
    public 
    view
    returns (uint) {
      (uint exoValue, uint keroValue) = getVaultsValues(id);
      return exoValue + keroValue;
  }

  function getVaultsValues( // in USD
    uint id
  ) 
    public 
    view
    returns (
      uint exoValue, // exo := exogenous (non-kerosene)
      uint keroValue
    ) {
      uint numberOfVaults = vaults[id].length(); 

      for (uint i = 0; i < numberOfVaults; i++) {
        Vault vault = Vault(vaults[id].at(i));
        if (vaultLicenser.isLicensed(address(vault))) {
          if (vaultLicenser.isKerosene(address(vault))) {
            keroValue += vault.getUsdValue(id);
          } else {
            exoValue  += vault.getUsdValue(id);
          }
        }
      }
  }

  // ----------------- MISC ----------------- //
  function getVaults(
    uint id
  ) 
    external 
    view 
    returns (address[] memory) {
      return vaults[id].values();
  }

  function hasVault(
    uint    id,
    address vault
  ) 
    external 
    view 
    returns (bool) {
      return vaults[id].contains(vault);
  }

  function authorizeExtension(address extension, bool isAuthorized) external {
    if (isAuthorized) {
      if (!DyadHooks.hookEnabled(_systemExtensions[extension], DyadHooks.EXTENSION_ENABLED)) {
        revert Unauthorized();
      }
      _authorizedExtensions[msg.sender].add(extension);
    } else {
      _authorizedExtensions[msg.sender].remove(extension);
    }
  }

  function authorizeSystemExtension(address extension, bool isAuthorized) external onlyOwner {
    if (isAuthorized) {
      uint256 hooks = IExtension(extension).getHookFlags();
      _systemExtensions[extension] = hooks | DyadHooks.EXTENSION_ENABLED;
    } else {
      _systemExtensions[extension] = DyadHooks.disableExtension(_systemExtensions[extension]);
    }
  }

  function isSystemExtension(address extension) external view returns (bool) {
    return DyadHooks.hookEnabled(_systemExtensions[extension], DyadHooks.EXTENSION_ENABLED);
  }

  function authorizedExtensions(address user) external view returns (address[] memory) {
    return _authorizedExtensions[user].values();
  }

  function isExtensionAuthorized(address user, address extension) public view returns (bool) {
    return _authorizedExtensions[user].contains(extension);
  }

  // ----------------- UPGRADABILITY ----------------- //
  function _authorizeUpgrade(address newImplementation) 
    internal 
    view
    override 
  {
    if (msg.sender != owner()) revert NotOwner();
  }

  function _authorizeCall(uint256 id) internal view returns (uint256) {
    address dnftOwner = dNft.ownerOf(id);
    if (dnftOwner != msg.sender) {
      uint256 extensionFlags = _systemExtensions[msg.sender];
      if (!DyadHooks.hookEnabled(extensionFlags, DyadHooks.EXTENSION_ENABLED)) {
        revert Unauthorized();
      }
      if (!_authorizedExtensions[dnftOwner].contains(msg.sender)) {
        revert Unauthorized();
      }
      return extensionFlags;
    }
    return 0;
  }
}