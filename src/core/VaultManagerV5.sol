// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DNft} from "./DNft.sol";
import {Dyad} from "./Dyad.sol";
import {VaultLicenser} from "./VaultLicenser.sol";
import {Vault} from "./Vault.sol";
import {IDyadXP} from "../interfaces/IDyadXP.sol";
import {IVaultManagerV5} from "../interfaces/IVaultManagerV5.sol";
import {Hooks} from "./Hooks.sol";
import "../interfaces/IExtension.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:oz-upgrades-from src/core/VaultManagerV4.sol:VaultManagerV4
contract VaultManagerV5 is IVaultManagerV5, UUPSUpgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    uint256 public constant MAX_VAULTS = 6;
    uint256 public constant MIN_COLLAT_RATIO = 1.5e18; // 150% // Collaterization
    uint256 public constant LIQUIDATION_REWARD = 0.2e18; //  20%

    address public constant KEROSENE_VAULT = 0x4808e4CC6a2Ba764778A0351E1Be198494aF0b43;

    DNft public dNft;
    Dyad public dyad;
    VaultLicenser public vaultLicenser;

    mapping(uint256 => EnumerableSet.AddressSet) internal vaults;
    mapping(uint256 /* id */ => uint256 /* block */) public lastDeposit;

    IDyadXP public dyadXP;

    /// @notice Extensions authorized for use in the system, with bitmap of enabled hooks
    mapping(address => uint256) private _systemExtensions;

    /// @notice Extensions authorized by a user for use on their notes
    mapping(address user => EnumerableSet.AddressSet) private _authorizedExtensions;

    modifier isDNftOwner(uint256 id) {
        if (dNft.ownerOf(id) != msg.sender) revert NotOwner();
        _;
    }

    modifier isValidDNft(uint256 id) {
        if (dNft.ownerOf(id) == address(0)) revert InvalidDNft();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public reinitializer(5) {}

    function add(uint256 id, address vault) external {
        _authorizeCall(id);
        if (!vaultLicenser.isLicensed(vault)) revert VaultNotLicensed();
        if (vaults[id].length() >= MAX_VAULTS) revert TooManyVaults();
        if (vaults[id].add(vault)) {
            emit Added(id, vault);
        }
    }

    function remove(uint256 id, address vault) external {
        _authorizeCall(id);
        if (vaults[id].remove(vault)) {
            if (Vault(vault).id2asset(id) > 0) {
                _checkExoValueAndCollatRatio(id);
            }
            emit Removed(id, vault);
        }
    }

    function deposit(uint256 id, address vault, uint256 amount) external isValidDNft(id) {
        _authorizeCall(id);
        lastDeposit[id] = block.number;
        Vault _vault = Vault(vault);
        _vault.asset().safeTransferFrom(msg.sender, vault, amount);
        _vault.deposit(id, amount);

        if (vault == KEROSENE_VAULT) {
            dyadXP.updateXP(id);
        }
    }

    function withdraw(uint256 id, address vault, uint256 amount, address to) public {
        uint256 extensionFlags = _authorizeCall(id);
        if (lastDeposit[id] == block.number) revert CanNotWithdrawInSameBlock();
        if (vault == KEROSENE_VAULT) dyadXP.beforeKeroseneWithdrawn(id, amount);
        Vault(vault).withdraw(id, to, amount); // changes `exo` or `kero` value and `cr`
        if (Hooks.hookEnabled(extensionFlags, Hooks.AFTER_WITHDRAW)) {
            IAfterWithdrawHook(msg.sender).afterWithdraw(id, vault, amount, to);
        }
        _checkExoValueAndCollatRatio(id);
    }

    function mintDyad(uint256 id, uint256 amount, address to) external {
        uint256 extensionFlags = _authorizeCall(id);
        dyad.mint(id, to, amount); // changes `mintedDyad` and `cr`
        if (Hooks.hookEnabled(extensionFlags, Hooks.AFTER_MINT)) {
            IAfterMintHook(msg.sender).afterMint(id, amount, to);
        }
        _checkExoValueAndCollatRatio(id);
        dyadXP.updateXP(id);
        emit MintDyad(id, amount, to);
    }

    function _checkExoValueAndCollatRatio(uint256 id) internal view {
        (uint256 exoValue, uint256 keroValue) = getVaultsValues(id);
        uint256 mintedDyad = dyad.mintedDyad(id);
        if (exoValue < mintedDyad) revert NotEnoughExoCollat();
        uint256 cr = _collatRatio(mintedDyad, exoValue + keroValue);
        if (cr < MIN_COLLAT_RATIO) revert CrTooLow();
    }

    function burnDyad(uint256 id, uint256 amount) public isValidDNft(id) {
        dyad.burn(id, msg.sender, amount);
        dyadXP.updateXP(id);
        emit BurnDyad(id, amount, msg.sender);
    }

    /// @notice Liquidates the specified note, transferring collateral to the specified note.
    /// @param id The note id
    /// @param to The address to transfer the collateral to
    /// @param amount The amount of dyad to liquidate
    function liquidate(uint256 id, uint256 to, uint256 amount)
        external
        isValidDNft(id)
        isValidDNft(to)
        returns (address[] memory, uint256[] memory)
    {
        uint256 cr = collatRatio(id);
        if (cr >= MIN_COLLAT_RATIO) revert CrTooHigh();
        uint256 debt = dyad.mintedDyad(id);
        dyad.burn(id, msg.sender, amount); // changes `debt` and `cr`

        lastDeposit[to] = block.number; // `move` acts like a deposit

        uint256 numberOfVaults = vaults[id].length();
        address[] memory vaultAddresses = new address[](numberOfVaults);
        uint256[] memory vaultAmounts = new uint256[](numberOfVaults);

        uint256 totalValue = getTotalValue(id);
        if (totalValue == 0) return (vaultAddresses, vaultAmounts);

        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault vault = Vault(vaults[id].at(i));
            vaultAddresses[i] = address(vault);
            if (vaultLicenser.isLicensed(address(vault))) {
                uint256 depositAmount = vault.id2asset(id);
                if (depositAmount == 0) continue;
                uint256 value = vault.getUsdValue(id);
                uint256 asset;
                if (cr < LIQUIDATION_REWARD + 1e18 && debt != amount) {
                    uint256 cappedCr = cr < 1e18 ? 1e18 : cr;
                    uint256 liquidationEquityShare = (cappedCr - 1e18).mulWadDown(LIQUIDATION_REWARD);
                    uint256 liquidationAssetShare = (liquidationEquityShare + 1e18).divWadDown(cappedCr);
                    uint256 allAsset = depositAmount.mulWadUp(liquidationAssetShare);
                    asset = allAsset.mulWadDown(amount).divWadDown(debt);
                } else {
                    uint256 share = value.divWadDown(totalValue);
                    uint256 amountShare = share.mulWadUp(amount);
                    uint256 reward_rate = amount.divWadDown(debt).mulWadDown(LIQUIDATION_REWARD);
                    uint256 valueToMove = amountShare + amountShare.mulWadUp(reward_rate);
                    uint256 cappedValue = valueToMove > value ? value : valueToMove;
                    asset = cappedValue * (10 ** (vault.oracle().decimals() + vault.asset().decimals()))
                        / vault.assetPrice() / 1e18;
                }
                vaultAmounts[i] = asset;

                vault.move(id, to, asset);
                if (address(vault) == KEROSENE_VAULT) {
                    dyadXP.updateXP(id);
                    dyadXP.updateXP(to);
                }
            }
        }

        emit Liquidate(id, msg.sender, to, amount);

        return (vaultAddresses, vaultAmounts);
    }

    function collatRatio(uint256 id) public view returns (uint256) {
        uint256 mintedDyad = dyad.mintedDyad(id);
        uint256 totalValue = getTotalValue(id);
        return _collatRatio(mintedDyad, totalValue);
    }

    /// @dev Why do we have the same function with different arguments?
    ///      Sometimes we can re-use the `mintedDyad` and `totalValue` values,
    ///      Calculating them is expensive, so we can re-use the cached values.
    function _collatRatio(
        uint256 mintedDyad,
        uint256 totalValue // in USD
    ) internal pure returns (uint256) {
        if (mintedDyad == 0) return type(uint256).max;
        return totalValue.divWadDown(mintedDyad);
    }

    function getTotalValue( // in USD
    uint256 id)
        public
        view
        returns (uint256)
    {
        (uint256 exoValue, uint256 keroValue) = getVaultsValues(id);
        return exoValue + keroValue;
    }

    function getVaultsValues( // in USD
    uint256 id)
        public
        view
        returns (
            uint256 exoValue, // exo := exogenous (non-kerosene)
            uint256 keroValue
        )
    {
        uint256 numberOfVaults = vaults[id].length();

        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault vault = Vault(vaults[id].at(i));
            if (vaultLicenser.isLicensed(address(vault))) {
                if (vaultLicenser.isKerosene(address(vault))) {
                    keroValue += vault.getUsdValue(id);
                } else {
                    exoValue += vault.getUsdValue(id);
                }
            }
        }
    }

    // ----------------- MISC ----------------- //
    function getVaults(uint256 id) external view returns (address[] memory) {
        return vaults[id].values();
    }

    function hasVault(uint256 id, address vault) external view returns (bool) {
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
            if (!Hooks.hookEnabled(_systemExtensions[extension], Hooks.EXTENSION_ENABLED)) {
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
            hooks = Hooks.enableExtension(IExtension(extension).getHookFlags());
        } else {
            hooks = Hooks.disableExtension(_systemExtensions[extension]);
        }
        _systemExtensions[extension] = hooks;
        emit SystemExtensionAuthorized(extension, hooks);
    }

    /// @notice Returns whether the specified extension is authorized for use in the system
    /// @param extension The extension address
    function isSystemExtension(address extension) external view returns (bool) {
        return Hooks.hookEnabled(_systemExtensions[extension], Hooks.EXTENSION_ENABLED);
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
    function _authorizeUpgrade(address newImplementation) internal override {
        if (msg.sender != owner()) revert NotOwner();
    }

    /// @dev Authorizes that the caller is either the owner of the specified note, or a system extension
    ///      that is both enabled and authorized by the owner of the note. Returns the extension flags if
    ///      the caller is an authorized extension. Reverts if the caller is not authorized.
    /// @param id The note id
    function _authorizeCall(uint256 id) internal view returns (uint256) {
        address dnftOwner = dNft.ownerOf(id);
        if (dnftOwner != msg.sender) {
            uint256 extensionFlags = _systemExtensions[msg.sender];
            if (!Hooks.hookEnabled(extensionFlags, Hooks.EXTENSION_ENABLED)) {
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
