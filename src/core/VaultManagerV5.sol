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

  uint256 public constant MAX_VAULTS         = 6;
  uint256 public constant MIN_COLLAT_RATIO   = 1.5e18; // 150% // Collaterization
  uint256 public constant LIQUIDATION_REWARD = 0.2e18; //  20%

  address public constant KEROSENE_VAULT = 0x4808e4CC6a2Ba764778A0351E1Be198494aF0b43;

  DNft          public dNft;
  Dyad          public dyad;
  VaultLicenser public vaultLicenser;

  mapping (uint256 id => EnumerableSet.AddressSet vaults) internal vaults; 
  mapping (uint256 id => uint256 block)  private lastDeposit; // not used anymore

  DyadXPv2 public dyadXP;

  // Extensions authorized for use in the system, with bitmap of enabled hooks
  mapping(address => uint256) private _systemExtensions;

  // Extensions authorized by a user for their use
  mapping(address user => EnumerableSet.AddressSet) private _authorizedExtensions;

  modifier isDNftOwner(uint256 id) {
    if (dNft.ownerOf(id) != msg.sender) revert NotOwner();    _;
  }
  modifier isValidDNft(uint256 id) {
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
      uint256 id,
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
      uint256 id,
      address vault
  ) 
    external
      isDNftOwner(id)
  {
    if (Vault(vault).id2asset(id) > 0) revert VaultHasAssets();
    if (!vaults[id].remove(vault))     revert VaultNotAdded();
    emit Removed(id, vault);
  }

  /// @notice Deposits collateral into the specified vault
  /// @param id The note id
  /// @param vault The vault address
  /// @param amount The amount to deposit
  function deposit(
    uint256 id,
    address vault,
    uint256 amount
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

  /// @notice Withdraws collateral from the specified vault.
  /// @dev Cannot withdraw exogenous collateral such that remaining value of exogenous collateral is
  ///      below the amount of minted dyad. Caller must be note owner or an extension authorized by
  ///      the note owner. If the caller is an authorized extension, may call back to the extension
  ///      before checking collateral ratio.
  /// @param id The note id
  /// @param vault The vault address
  /// @param amount The amount to withdraw
  /// @param to The address to send the withdrawn collateral to
  function withdraw(
    uint256 id,
    address vault,
    uint256 amount,
    address to
  ) 
    public
  {
    uint256 extensionFlags = _authorizeCall(id);
    _withdraw(id, vault, amount, to, extensionFlags);
  }

  function _withdraw(
    uint256 id,
    address vault,
    uint256 amount,
    address to,
    uint256 extensionFlags
  ) 
    internal
  {
    if (vault == KEROSENE_VAULT) dyadXP.beforeKeroseneWithdrawn(id, amount);
    Vault(vault).withdraw(id, to, amount); // changes `exo` or `kero` value and `cr`
    if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_WITHDRAW)) {
      IAfterWithdrawHook(msg.sender).afterWithdraw(id, vault, amount, to);
    }
    _checkExoValueAndCollatRatio(id);
  }

  /// @notice Mints dyad for the specified note.
  /// @dev Total minted dyad must be less than total value of all exogenous collateral for the note,
  ///      and collateral ratio must be above the minimum. Caller must be note owner or an extension
  ///      authorized by the note owner. If the caller is an authorized extension, may call back to
  ///      the extension before checking collateral ratio.
  /// @param id The note id
  /// @param amount The amount of dyad to mint
  /// @param to The address to send the minted dyad to
  function mintDyad(
    uint256 id,
    uint256 amount,
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

  /// @notice Burns dyad for the specified note, repaying debt.
  /// @dev If the caller is an authorized system extension, may call back to the extension after
  ///      dyad is burned
  /// @param id The note id
  /// @param amount The amount of dyad to burn
  function burnDyad(
    uint256 id,
    uint256 amount
  ) 
    public isValidDNft(id)
  {
    uint256 extensionFlags = _systemExtensions[msg.sender];
    _burnDyad(id, amount, extensionFlags);
  }

  function _burnDyad(uint256 id, uint256 amount, uint256 extensionFlags) internal {
    dyad.burn(id, msg.sender, amount);
    dyadXP.afterDyadBurned(id);
    if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.EXTENSION_ENABLED)) {
      if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_BURN)) {
        IAfterBurnHook(msg.sender).afterBurn(id, amount);
      }
    }
    emit BurnDyad(id, amount, msg.sender);
  }

  /// @notice Redeems dyad against the specified note, withdrawing collateral.
  /// @dev Caller must be note owner or an extension authorized by the note owner. If the caller is
  ///      an authorized extension, may call back to the extension after dyad is burned. If the caller
  ///      is an authorized system extension, may call back to the extension after burn, withdraw, 
  ///      or redeem steps.
  /// @param id The note id
  function redeemDyad(
    uint256    id,
    address vault,
    uint256    amount,
    address to
  )
    external 
    returns (uint) { 
      uint256 extensionFlags = _authorizeCall(id);
      _burnDyad(id, amount, extensionFlags);
      Vault _vault = Vault(vault);
      uint asset = amount 
                    * (10**(_vault.oracle().decimals() + _vault.asset().decimals())) 
                    / _vault.assetPrice() 
                    / 1e18;
      _withdraw(id, vault, asset, to, extensionFlags);
      emit RedeemDyad(id, vault, amount, to);
      return asset;
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
      uint cr = collatRatio(id);
      if (cr >= MIN_COLLAT_RATIO) revert CrTooHigh();
      uint debt = dyad.mintedDyad(id);
      dyad.burn(id, msg.sender, amount); // changes `debt` and `cr`

      uint numberOfVaults = vaults[id].length();
      address[] memory vaultAddresses = new address[](numberOfVaults);
      uint[] memory vaultAmounts = new uint[](numberOfVaults);

      uint totalValue = getTotalValue(id);
      if (totalValue == 0) return (vaultAddresses, vaultAmounts);

      for (uint i = 0; i < numberOfVaults; i++) {
        Vault vault = Vault(vaults[id].at(i));
        vaultAddresses[i] = address(vault);
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
          vaultAmounts[i] = asset;
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

      return (vaultAddresses, vaultAmounts);
  }

  /// @notice Returns the collateral ratio for the specified note.
  /// @param id The note id
  function collatRatio(
    uint256 id
  )
    public 
    view
    returns (uint) {
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
    returns (uint) {
      if (mintedDyad == 0) return type(uint).max;
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
      (uint exoValue, uint keroValue) = getVaultsValues(id);
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
  /// @notice Returns the registered vaults for the specified note
  /// @param id The note id
  function getVaults(
    uint id
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
    uint    id,
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
    if (isAuthorized) {
      if (!DyadHooks.hookEnabled(_systemExtensions[extension], DyadHooks.EXTENSION_ENABLED)) {
        revert Unauthorized();
      }
      _authorizedExtensions[msg.sender].add(extension);
    } else {
      _authorizedExtensions[msg.sender].remove(extension);
    }
  }

  /// @notice Authorizes an extension for use in the system
  /// @param extension The extension address
  /// @param isAuthorized Whether the extension is authorized
  function authorizeSystemExtension(address extension, bool isAuthorized) external onlyOwner {
    if (isAuthorized) {
      uint256 hooks = IExtension(extension).getHookFlags();
      _systemExtensions[extension] = hooks | DyadHooks.EXTENSION_ENABLED;
    } else {
      _systemExtensions[extension] = DyadHooks.disableExtension(_systemExtensions[extension]);
    }
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
