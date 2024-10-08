// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DNft}          from "./DNft.sol";
import {Dyad}          from "./Dyad.sol";
import {VaultLicenser} from "./VaultLicenser.sol";
import {Vault}         from "./Vault.sol";
import {Staking}       from "../staking/Staking.sol";
import {Ignition}      from "../staking/Ignition.sol";
import {IVaultManagerV5} from "../interfaces/IVaultManagerV5.sol";
import {DyadHooks}       from "./DyadHooks.sol";
import "../interfaces/IExtension.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {ERC20}             from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib}   from "@solmate/src/utils/SafeTransferLib.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC1967Proxy}  from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable}    from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:oz-upgrades-from src/core/VaultManagerV4.sol:VaultManagerV4
contract VaultManagerV5 is IVaultManagerV5, UUPSUpgradeable, OwnableUpgradeable {
  using EnumerableSet     for EnumerableSet.AddressSet;
  using FixedPointMathLib for uint;
  using SafeTransferLib   for ERC20;

  uint256 public constant MAX_VAULTS         = 6;
  uint256 public constant MIN_COLLAT_RATIO   = 1.5e18; // 150% // Collaterization
  uint256 public constant LIQUIDATION_REWARD = 0.2e18; //  20%

  address public constant KEROSENE_VAULT = 0x4808e4CC6a2Ba764778A0351E1Be198494aF0b43;

  DNft          public dNft;
  Dyad          public dyad;
  VaultLicenser public vaultLicenser;

  mapping (uint256 id => EnumerableSet.AddressSet vaults) internal vaults; 
  mapping (uint256 id => uint256 block)  private lastDeposit;

  Staking public staking;

  /// @notice Extensions authorized for use in the system, with bitmap of enabled hooks
  mapping(address => uint256) private _systemExtensions;

  /// @notice Extensions authorized by a user for use on their notes
  mapping(address user => EnumerableSet.AddressSet) private _authorizedExtensions;

  modifier isValidDNft(uint256 id) {
    if (dNft.ownerOf(id) == address(0)) revert InvalidDNft(); _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() { _disableInitializers(); }

  function initialize(Staking _staking)
    public 
      reinitializer(5) 
  {
    staking = _staking;
  }

  /// @inheritdoc IVaultManagerV5
  function add(
      uint256 id,
      address vault
  ) 
    external
  {
    _authorizeCall(id);
    if (!vaultLicenser.isLicensed(vault))   revert VaultNotLicensed();
    if ( vaults[id].length() >= MAX_VAULTS) revert TooManyVaults();
    if (vaults[id].add(vault)) {
      emit Added(id, vault);
    }
  }

  /// @inheritdoc IVaultManagerV5
  function remove(
      uint256 id,
      address vault
  )
    external
  {
    _authorizeCall(id);
    if (vaults[id].remove(vault)) {
      if (Vault(vault).id2asset(id) > 0) {
        _checkExoValueAndCollatRatio(id);
      }
      emit Removed(id, vault);
    }
  }

  /// @inheritdoc IVaultManagerV5
  function deposit(
    uint256 id,
    address vault,
    uint256 amount
  ) 
    external isValidDNft(id)
  {
    _authorizeCall(id);
    lastDeposit[id] = block.number;
    Vault _vault = Vault(vault);
    _vault.asset().safeTransferFrom(msg.sender, vault, amount);
    _vault.deposit(id, amount);
  }

  /// @inheritdoc IVaultManagerV5
  function withdraw(
    uint256 id,
    address vault,
    uint256 amount,
    address to
  ) 
    public
  {
    uint256 extensionFlags = _authorizeCall(id);
    if (lastDeposit[id] == block.number) revert CanNotWithdrawInSameBlock();
    Vault(vault).withdraw(id, to, amount); // changes `exo` or `kero` value and `cr`
    if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_WITHDRAW)) {
      IAfterWithdrawHook(msg.sender).afterWithdraw(id, vault, amount, to);
    }
    _checkExoValueAndCollatRatio(id);
  }

  //// @inheritdoc IVaultManagerV5
  function mintDyad(
    uint256 id,
    uint256 amount,
    address to
  )
    external 
  {
    uint256 extensionFlags = _authorizeCall(id);
    dyad.mint(id, to, amount); // changes `mintedDyad` and `cr`
    staking.updateBoost(id);
    if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_MINT)) {
      IAfterMintHook(msg.sender).afterMint(id, amount, to);
    }
    _checkExoValueAndCollatRatio(id);
    emit MintDyad(id, amount, to);
  }

  /// @notice Checks the exogenous collateral value and collateral ratio for the specified note.
  /// @dev Reverts if the exogenous collateral value is less than the minted dyad or the collateral
  ///      ratio is below the minimum.
  function _checkExoValueAndCollatRatio(
    uint256 id
  ) 
    internal
    view
  {
    (uint256 exoValue, uint256 keroValue) = getVaultsValues(id);
    uint256 mintedDyad = dyad.mintedDyad(id);
    if (exoValue < mintedDyad) {
      revert NotEnoughExoCollat();
    }
    uint256 cr = _collatRatio(mintedDyad, exoValue + keroValue);
    if (cr < MIN_COLLAT_RATIO) {
      revert CrTooLow();
    }
  }

  /// @inheritdoc IVaultManagerV5
  function burnDyad(
    uint256 id,
    uint256 amount
  ) 
    public isValidDNft(id)
  {
    dyad.burn(id, msg.sender, amount);
    staking.updateBoost(id);
    emit BurnDyad(id, amount, msg.sender);
  }

  /// @notice Liquidates the specified note, transferring collateral to the specified note.
  /// @param id The note id
  /// @param to The address to transfer the collateral to
  /// @param amount The amount of dyad to liquidate
  function liquidate(
    uint256 id,
    uint256 to,
    uint256 amount
  ) 
    external 
    isValidDNft(id)
    isValidDNft(to)
    returns (address[] memory, uint[] memory)
  {
    uint256 cr = collatRatio(id);
    if (cr >= MIN_COLLAT_RATIO) revert CrTooHigh();
    uint256 debt = dyad.mintedDyad(id);
    dyad.burn(id, msg.sender, amount); // changes debt and cr
    staking.updateBoost(id);

    lastDeposit[to] = block.number; // move acts like a deposit

    uint256 numberOfVaults = vaults[id].length();
    address[] memory vaultAddresses = new address[](numberOfVaults);
    uint[] memory vaultAmounts = new uint[](numberOfVaults);

    // Separate exogenous and kerosene values
    (uint256 exoValue, uint256 keroValue) = getVaultsValues(id);
    uint256 totalValue = exoValue + keroValue;
    if (totalValue == 0) return (vaultAddresses, vaultAmounts);

    uint256 amountLeft = amount;
    uint256 vaultIndex = 0;

    // Process non-kerosene (exogenous) vaults first
    if (exoValue > 0) {
        uint256 amountFromExoVaults = amountLeft <= exoValue ? amountLeft : exoValue;
        amountLeft -= amountFromExoVaults;

        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault vault = Vault(vaults[id].at(i));
            if (vaultLicenser.isLicensed(address(vault)) && !vaultLicenser.isKerosene(address(vault))) {
                vaultAddresses[vaultIndex] = address(vault);
                uint256 depositAmount = vault.id2asset(id);
                if (depositAmount == 0) continue;
                uint256 value = vault.getUsdValue(id);

                // Calculate the share of the amount to cover from this vault
                uint256 share = value.divWadDown(exoValue);
                uint256 amountShare = share.mulWadUp(amountFromExoVaults);

                // Adjust calculations based on the original logic
                uint256 asset = _calculateAssetToMove(id, vault, cr, debt, amount, amountShare, value);

                vaultAmounts[vaultIndex] = asset;
                vault.move(id, to, asset);
                vaultIndex++;
            }
        }
    }

    // Process kerosene vaults if there's still an amount left
    if (amountLeft > 0 && keroValue > 0) {
        uint256 amountFromKeroVaults = amountLeft <= keroValue ? amountLeft : keroValue;
        amountLeft -= amountFromKeroVaults;

        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault vault = Vault(vaults[id].at(i));
            if (vaultLicenser.isLicensed(address(vault)) && vaultLicenser.isKerosene(address(vault))) {
                vaultAddresses[vaultIndex] = address(vault);
                uint256 depositAmount = vault.id2asset(id);
                if (depositAmount == 0) continue;
                uint256 value = vault.getUsdValue(id);

                // Calculate the share of the amount to cover from this vault
                uint256 share = value.divWadDown(keroValue);
                uint256 amountShare = share.mulWadUp(amountFromKeroVaults);

                // Adjust calculations based on the original logic
                uint256 asset = _calculateAssetToMove(id, vault, cr, debt, amount, amountShare, value);

                vaultAmounts[vaultIndex] = asset;
                vault.move(id, to, asset);
                vaultIndex++;
            }
        }
    }

    emit Liquidate(id, msg.sender, to, amount);

    return (vaultAddresses, vaultAmounts);
  }

  // Helper function to calculate the asset amount to move
  function _calculateAssetToMove(
      uint256 id,
      Vault vault,
      uint256 cr,
      uint256 debt,
      uint256 amount,
      uint256 amountShare,
      uint256 value
  ) internal view returns (uint256 asset) {
      if (cr < LIQUIDATION_REWARD + 1e18 && debt != amount) {
          uint256 cappedCr               = cr < 1e18 ? 1e18 : cr;
          uint256 liquidationEquityShare = (cappedCr - 1e18).mulWadDown(LIQUIDATION_REWARD);
          uint256 liquidationAssetShare  = (liquidationEquityShare + 1e18).divWadDown(cappedCr);
          uint256 allAsset = vault.id2asset(id).mulWadUp(liquidationAssetShare);
          asset = allAsset.mulWadDown(amount).divWadDown(debt);
      } else {
          uint256 reward_rate = amount
                              .divWadDown(debt)
                              .mulWadDown(LIQUIDATION_REWARD);
          uint256 valueToMove = amountShare + amountShare.mulWadUp(reward_rate);
          uint256 cappedValue = valueToMove > value ? value : valueToMove;
          asset = cappedValue 
                  * (10**(vault.oracle().decimals() + vault.asset().decimals())) 
                  / vault.assetPrice() 
                  / 1e18;
      }
  }

  /// @notice Returns the collateral ratio for the specified note.
  /// @param id The note id
  function collatRatio(
    uint256 id
  )
    public 
    view
    returns (uint256) {
      uint256 mintedDyad = dyad.mintedDyad(id);
      uint256 totalValue = getTotalValue(id);
      return _collatRatio(mintedDyad, totalValue);
  }

  /// @dev Internal function for computing collateral ratio. Reading `mintedDyad` and `totalValue`
  ///      is expensive. If we already have these values loaded, we can re-use the cached values.
  /// @param mintedDyad The amount of dyad minted for the note
  /// @param totalValue The total value of all exogenous collateral for the note
  function _collatRatio(
    uint256 mintedDyad, 
    uint256 totalValue // in USD
  )
    internal 
    pure
    returns (uint256) {
      if (mintedDyad == 0) return type(uint256).max;
      return totalValue.divWadDown(mintedDyad);
  }

  /// @notice Returns the total value of all exogenous and kerosene collateral for the specified note.
  /// @param id The note id
  function getTotalValue( // in USD
    uint256 id
  ) 
    public 
    view
    returns (uint256) {
      (uint256 exoValue, uint256 keroValue) = getVaultsValues(id);
      return exoValue + keroValue;
  }

  /// @notice Returns the USD value of all exogenous and kerosene collateral for the specified note.
  /// @param id The note id
  function getVaultsValues( // in USD
    uint256 id
  ) 
    public 
    view
    returns (
      uint256 exoValue, // exo := exogenous (non-kerosene)
      uint256 keroValue
    ) {
      uint256 numberOfVaults = vaults[id].length(); 

      for (uint256 i = 0; i < numberOfVaults; i++) {
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
  /// @notice Returns the registered vaults for the specified note
  /// @param id The note id
  function getVaults(
    uint256 id
  ) 
    external 
    view 
    returns (address[] memory) {
      return vaults[id].values();
  }

  /// @notice Returns whether the specified vault is registered for the specified note
  /// @param id The note id
  /// @param vault The vault address
  function hasVault(
    uint256    id,
    address vault
  ) 
    external 
    view 
    returns (bool) {
      return vaults[id].contains(vault);
  }

  /// @notice Authorizes an extension for use by current user
  /// @dev Can not authorize an extension that is not a registered and enabled system extension,
  ///      but can deauthorize it
  /// @param extension The extension address
  /// @param isAuthorized Whether the extension is authorized
  function authorizeExtension(address extension, bool isAuthorized) external {
    bool authorizationChanged = false;
    if (isAuthorized) {
      if (!DyadHooks.hookEnabled(_systemExtensions[extension], DyadHooks.EXTENSION_ENABLED)) {
        revert Unauthorized();
      }
      authorizationChanged = _authorizedExtensions[msg.sender].add(extension);
    } else {
      authorizationChanged = _authorizedExtensions[msg.sender].remove(extension);
    }
    if (authorizationChanged) {
      emit UserExtensionAuthorized(msg.sender, extension, isAuthorized);
    }
  }

  /// @notice Authorizes an extension for use in the system
  /// @param extension The extension address
  /// @param isAuthorized Whether the extension is authorized
  function authorizeSystemExtension(address extension, bool isAuthorized) external onlyOwner {
    uint256 hooks;
    if (isAuthorized) {
      hooks = DyadHooks.enableExtension(IExtension(extension).getHookFlags());
    } else {
      hooks = DyadHooks.disableExtension(_systemExtensions[extension]);
    }
    _systemExtensions[extension] = hooks;
    emit SystemExtensionAuthorized(extension, hooks);
  }

  /// @notice Returns whether the specified extension is authorized for use in the system
  /// @param extension The extension address
  function isSystemExtension(address extension) external view returns (bool) {
    return DyadHooks.hookEnabled(_systemExtensions[extension], DyadHooks.EXTENSION_ENABLED);
  }

  /// @notice Returns the authorized extensions for the specified user
  /// @param user The user address
  function authorizedExtensions(address user) external view returns (address[] memory) {
    return _authorizedExtensions[user].values();
  }

  /// @notice Returns whether the specified extension is authorized for use by the specified user
  /// @param user The user address
  /// @param extension The extension address
  function isExtensionAuthorized(address user, address extension) public view returns (bool) {
    return _authorizedExtensions[user].contains(extension);
  }

  // ----------------- UPGRADABILITY ----------------- //
  /// @dev UUPS upgrade authorization - only owner can upgrade
  function _authorizeUpgrade(address) 
    internal 
    view
    override
    onlyOwner
  {
  }

  /// @dev Authorizes that the caller is either the owner of the specified note, or a system extension
  ///      that is both enabled and authorized by the owner of the note. Returns the extension flags if
  ///      the caller is an authorized extension. Reverts if the caller is not authorized.
  /// @param id The note id 
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