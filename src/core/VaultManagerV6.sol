// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DNft} from "./DNft.sol";
import {Dyad} from "./Dyad.sol";
import {VaultLicenser} from "./VaultLicenser.sol";
import {Vault} from "./Vault.sol";
import {DyadXP} from "../staking/DyadXP.sol";
import {IVaultManagerV5} from "../interfaces/IVaultManagerV5.sol";
import {DyadHooks} from "./DyadHooks.sol";
import "../interfaces/IExtension.sol";
import {KeroseneValuer} from "../staking/KeroseneValuer.sol";
import {KerosineManager} from "../core/KerosineManager.sol";
import {IInterestVault} from "../interfaces/IInterestVault.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:oz-upgrades-from src/core/VaultManagerV4.sol:VaultManagerV4
contract VaultManagerV6 is IVaultManagerV5, UUPSUpgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    uint256 public constant MAX_VAULTS = 6;
    uint256 public constant MIN_COLLAT_RATIO = 1.5e18; // 150% // Collaterization
    uint256 public constant LIQUIDATION_REWARD = 0.2e18; //  20%
    uint256 public constant INTEREST_PRECISION = 1e27;
    uint256 public constant MAX_INTEREST_RATE_IN_BPS = 400; // 4%

    address public constant KEROSENE_VAULT = 0x4808e4CC6a2Ba764778A0351E1Be198494aF0b43;

    DNft public dNft;
    Dyad public dyad;
    VaultLicenser public vaultLicenser;

    mapping(uint256 id => EnumerableSet.AddressSet vaults) internal vaults;
    mapping(uint256 id => uint256 block) private lastDeposit;

    DyadXP public dyadXP;

    /// @notice Extensions authorized for use in the system, with bitmap of enabled hooks
    mapping(address => uint256) private _systemExtensions;

    /// @notice Extensions authorized by a user for use on their notes
    mapping(address user => EnumerableSet.AddressSet) private _authorizedExtensions;

    KeroseneValuer public keroseneValuer;
    IInterestVault public interestVault;

    mapping(uint256 noteId => uint256 activeInterestIndex) public noteInterestIndex;
    uint256 public interestRate;
    uint256 public lastInterestIndexUpdate;
    uint256 public claimableInterest;

    mapping(uint256 noteId => uint256 debt) internal _noteDebtSnapshot;
    uint256 internal _lastInterestIndex;
    uint256 internal _activeDebtSnapshot;

    modifier isValidDNft(uint256 id) {
        if (dNft.ownerOf(id) == address(0)) revert InvalidDNft();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _keroseneValuer, address _interestVault) public reinitializer(6) {
        interestVault = IInterestVault(_interestVault);
        keroseneValuer = KeroseneValuer(_keroseneValuer);

        uint256 interestIndex = INTEREST_PRECISION;
        _lastInterestIndex = interestIndex;
        lastInterestIndexUpdate = block.timestamp;

        uint256 totalNotes = dNft.totalSupply();
        Dyad dyadCached = dyad;

        for (uint256 i; i < totalNotes; i++) {
            noteInterestIndex[i] = interestIndex;

            uint256 mintedDyad = dyadCached.mintedDyad(i);
            if (mintedDyad > 0) {
                _noteDebtSnapshot[i] += mintedDyad;
            }
        }

        _activeDebtSnapshot = dyadCached.totalSupply();
    }

    function setKeroseneValuer(address _newKeroseneValuer) external onlyOwner {
        keroseneValuer = KeroseneValuer(_newKeroseneValuer);
    }

    function setInterestRate(uint256 _newInterestRateBps) external onlyOwner {
        if (_newInterestRateBps > MAX_INTEREST_RATE_IN_BPS) {
            revert("Interest rate too high");
        }
        uint256 newInterestRate = _newInterestRateBps.mulDivUp(INTEREST_PRECISION, 10000 * 365 days);

        if (newInterestRate != interestRate) {
            _accrueGlobalActiveInterest();

            interestRate = newInterestRate;
        }
    }

    function claimInterest() external onlyOwner returns (uint256) {
        _accrueGlobalActiveInterest();

        uint256 interestToClaim = claimableInterest;

        if (interestToClaim > 0) {
            claimableInterest = 0;
            interestVault.mintInterest(interestToClaim);
        }

        return interestToClaim;
    }

    /// @inheritdoc IVaultManagerV5
    function add(uint256 id, address vault) external {
        _authorizeCall(id);
        _accrueNoteInterest(id);
        if (!vaultLicenser.isLicensed(vault)) revert VaultNotLicensed();
        if (vaults[id].length() >= MAX_VAULTS) revert TooManyVaults();
        if (vaults[id].add(vault)) {
            emit Added(id, vault);
        }
    }

    /// @inheritdoc IVaultManagerV5
    function remove(uint256 id, address vault) external {
        _authorizeCall(id);
        _accrueNoteInterest(id);
        if (vaults[id].remove(vault)) {
            if (Vault(vault).id2asset(id) > 0) {
                if (vaultLicenser.isLicensed(vault)) {
                    _checkExoValueAndCollatRatio(id);
                }
            }
            emit Removed(id, vault);
        }
    }

    /// @inheritdoc IVaultManagerV5
    function deposit(uint256 id, address vault, uint256 amount) external isValidDNft(id) {
        _authorizeCall(id);
        _accrueNoteInterest(id);
        lastDeposit[id] = block.number;
        Vault _vault = Vault(vault);
        _vault.asset().safeTransferFrom(msg.sender, vault, amount);
        _vault.deposit(id, amount);

        if (vault == KEROSENE_VAULT) {
            dyadXP.afterKeroseneDeposited(id, amount);
        }
    }

    /// @inheritdoc IVaultManagerV5
    function withdraw(uint256 id, address vault, uint256 amount, address to) public {
        uint256 extensionFlags = _authorizeCall(id);
        _accrueNoteInterest(id);
        if (lastDeposit[id] == block.number) revert CanNotWithdrawInSameBlock();
        if (vault == KEROSENE_VAULT) dyadXP.beforeKeroseneWithdrawn(id, amount);
        Vault(vault).withdraw(id, to, amount); // changes `exo` or `kero` value and `cr`
        if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_WITHDRAW)) {
            IAfterWithdrawHook(msg.sender).afterWithdraw(id, vault, amount, to);
        }
        _checkExoValueAndCollatRatio(id);
    }

    //// @inheritdoc IVaultManagerV5
    function mintDyad(uint256 id, uint256 amount, address to) external {
        uint256 extensionFlags = _authorizeCall(id);
        dyad.mint(id, to, amount); // changes `mintedDyad` and `cr`
        uint256 currentNoteDebt = _accrueNoteInterest(id);

        _activeDebtSnapshot += amount;
        _noteDebtSnapshot[id] = currentNoteDebt + amount;

        if (DyadHooks.hookEnabled(extensionFlags, DyadHooks.AFTER_MINT)) {
            IAfterMintHook(msg.sender).afterMint(id, amount, to);
        }
        _checkExoValueAndCollatRatio(id);
        emit MintDyad(id, amount, to);
    }

    /// @notice Checks the exogenous collateral value and collateral ratio for the specified note.
    /// @dev Reverts if the exogenous collateral value is less than the minted dyad or the collateral
    ///      ratio is below the minimum.
    function _checkExoValueAndCollatRatio(uint256 id) internal view {
        (, uint256 exoValue,, uint256 cr, uint256 mintedDyad) = _totalVaultValuesAndCr(id);
        if (exoValue < mintedDyad) {
            revert NotEnoughExoCollat();
        }
        if (cr < MIN_COLLAT_RATIO) {
            revert CrTooLow();
        }
    }

    /// @inheritdoc IVaultManagerV5
    function burnDyad(uint256 id, uint256 amount) public isValidDNft(id) {
        dyad.burn(id, msg.sender, amount);
        uint256 currentNoteDebt = _accrueNoteInterest(id);
        _activeDebtSnapshot -= amount;
        _noteDebtSnapshot[id] = currentNoteDebt - amount;
        if (currentNoteDebt == amount) {
            noteInterestIndex[id] = 0;
        }
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
        uint256 currentNoteDebt = _accrueNoteInterest(id);
        _accrueNoteInterest(to);

        (uint256[] memory vaultsValues, uint256 exoValue, uint256 keroValue, uint256 cr, uint256 debt) =
            _totalVaultValuesAndCr(id);

        if (cr >= MIN_COLLAT_RATIO) {
            revert CrTooHigh();
        }

        dyad.burn(id, msg.sender, amount); // changes `debt` and `cr`
        if (currentNoteDebt == amount) {
            noteInterestIndex[id] = 0;
        }

        _noteDebtSnapshot[id] = currentNoteDebt - amount;
        _activeDebtSnapshot -= amount;

        lastDeposit[to] = block.number; // `move` acts like a deposit

        uint256 numberOfVaults = vaults[id].length();
        address[] memory vaultAddresses = new address[](numberOfVaults);
        uint256[] memory vaultAmounts = new uint256[](numberOfVaults);

        uint256 totalValue = exoValue + keroValue;
        if (totalValue == 0) {
            return (vaultAddresses, vaultAmounts);
        }

        uint256 totalLiquidationReward;
        if (cr < LIQUIDATION_REWARD + 1e18 && debt != amount) {
            uint256 cappedCr = cr < 1e18 ? 1e18 : cr;
            uint256 liquidationEquityShare = (cappedCr - 1e18).mulWadDown(LIQUIDATION_REWARD);
            uint256 liquidationAssetShare = (liquidationEquityShare + 1e18).divWadDown(cappedCr);
            uint256 allAsset = totalValue.mulWadUp(liquidationAssetShare);
            totalLiquidationReward = allAsset.mulWadDown(amount).divWadDown(debt);
        } else {
            totalLiquidationReward = amount + amount.mulWadDown(LIQUIDATION_REWARD);
            if (totalLiquidationReward < totalValue) {
                totalLiquidationReward = totalValue;
            }
        }

        uint256 amountMoved;
        uint256 keroIndex;
        for (uint256 i; i < numberOfVaults; ++i) {
            Vault vault = Vault(vaults[id].at(i));
            vaultAddresses[i] = address(vault);
            if (address(vault) == KEROSENE_VAULT) {
                keroIndex = i;
                continue;
            }
            if (vaultLicenser.isLicensed(address(vault))) {
                uint256 value = vaultsValues[i];
                if (value == 0) continue;
                uint256 depositAmount = vault.id2asset(id);
                uint256 percentageOfValue = value.divWadDown(exoValue);
                uint256 valueToMove = percentageOfValue.mulWadDown(totalLiquidationReward);
                uint256 asset = depositAmount.mulWadDown(valueToMove).divWadDown(value);
                if (asset > depositAmount) {
                    asset = depositAmount;
                    amountMoved += value;
                } else {
                    amountMoved += valueToMove;
                }
                vault.move(id, to, asset);
            }
        }

        if (keroValue > 0 && amountMoved < totalLiquidationReward) {
            uint256 amountRemaining = totalLiquidationReward - amountMoved;
            uint256 keroDeposited = Vault(KEROSENE_VAULT).id2asset(id);
            uint256 keroToMove = keroDeposited.mulWadDown(amountRemaining).divWadDown(keroValue);
            if (keroToMove > keroDeposited) {
                keroToMove = keroDeposited;
            }
            vaultAmounts[keroIndex] = keroToMove;
            dyadXP.beforeKeroseneWithdrawn(id, keroToMove);
            Vault(KEROSENE_VAULT).move(id, to, keroToMove);
            dyadXP.afterKeroseneDeposited(to, keroToMove);
        }

        emit Liquidate(id, msg.sender, to, amount);

        return (vaultAddresses, vaultAmounts);
    }

    /// @notice Returns the collateral ratio for the specified note.
    /// @param id The note id
    function collatRatio(uint256 id) external view returns (uint256) {
        (,,, uint256 cr,) = _totalVaultValuesAndCr(id);
        return cr;
    }

    /// @dev Internal function for computing collateral ratio. Reading `mintedDyad` and `totalValue`
    ///      is expensive. If we already have these values loaded, we can re-use the cached values.
    /// @param mintedDyad The amount of dyad minted for the note
    /// @param totalValue The total value of all exogenous collateral for the note
    function _collatRatio(
        uint256 mintedDyad,
        uint256 totalValue // in USD
    ) internal pure returns (uint256) {
        if (mintedDyad == 0) return type(uint256).max;
        return totalValue.divWadDown(mintedDyad);
    }

    /// @notice Returns the total value of all exogenous and kerosene collateral for the specified note.
    /// @param id The note id
    function getTotalValue( // in USD
    uint256 id)
        external
        view
        returns (uint256)
    {
        (, uint256 exoValue, uint256 keroValue,,) = _totalVaultValuesAndCr(id);
        return exoValue + keroValue;
    }

    /// @notice Returns the USD value of all exogenous and kerosene collateral for the specified note.
    /// @param id The note id
    function getVaultsValues( // in USD
    uint256 id)
        external
        view
        returns (
            uint256 exoValue, // exo := exogenous (non-kerosene)
            uint256 keroValue
        )
    {
        (, exoValue, keroValue,,) = _totalVaultValuesAndCr(id);
        return (exoValue, keroValue);
    }

    // ----------------- MISC ----------------- //
    /// @notice Returns the registered vaults for the specified note
    /// @param id The note id
    function getVaults(uint256 id) external view returns (address[] memory) {
        return vaults[id].values();
    }

    /// @notice Returns whether the specified vault is registered for the specified note
    /// @param id The note id
    /// @param vault The vault address
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

    function _totalVaultValuesAndCr(uint256 id)
        private
        view
        returns (uint256[] memory vaultValues, uint256 exoValue, uint256 keroValue, uint256 cr, uint256 mintedDyad)
    {
        uint256 numberOfVaults = vaults[id].length();
        vaultValues = new uint256[](numberOfVaults);

        uint256 keroseneVaultIndex;
        uint256 noteKeroseneAmount;

        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault vault = Vault(vaults[id].at(i));
            if (vaultLicenser.isLicensed(address(vault))) {
                if (vaultLicenser.isKerosene(address(vault))) {
                    noteKeroseneAmount = vault.id2asset(id);
                    keroseneVaultIndex = i;
                    continue;
                } else {
                    uint256 value = vault.getUsdValue(id);
                    vaultValues[i] = value;
                    exoValue += value;
                }
            }
        }

        if (noteKeroseneAmount > 0) {
            keroValue = (noteKeroseneAmount * keroseneValuer.deterministicValue()) / 1e8;
            vaultValues[keroseneVaultIndex] = keroValue;
        }

        mintedDyad = _noteDebtSnapshot[id];
        uint256 totalValue = exoValue + keroValue;
        cr = _collatRatio(mintedDyad, totalValue);

        return (vaultValues, exoValue, keroValue, cr, mintedDyad);
    }

    function getNoteDebt(uint256 _noteID) external view returns (uint256) {
        (uint256 globalInterestIndex,) = _calculateInterestIndex();
        uint256 interestIndex = noteInterestIndex[_noteID];

        uint256 debt = _noteDebtSnapshot[_noteID];

        if (interestIndex > 0 && interestIndex < globalInterestIndex) {
            debt = debt.mulDivUp(globalInterestIndex, interestIndex);
        }

        return debt;
    }

    function getTotalDebt() external view returns (uint256) {
        (, uint256 interestFactor) = _calculateInterestIndex();

        uint256 debt = _activeDebtSnapshot;

        return debt + debt.mulDivUp(interestFactor, INTEREST_PRECISION);
    }

    function activeInterestIndex() external view returns (uint256) {
        (uint256 interestIndex,) = _calculateInterestIndex();

        return interestIndex;
    }

    function _accrueNoteInterest(uint256 _noteID) internal returns (uint256) {
        uint256 interestIndex = noteInterestIndex[_noteID];
        uint256 currentInterestIndex = _accrueGlobalActiveInterest();

        uint256 debt = _noteDebtSnapshot[_noteID];

        if (interestIndex == 0) {
            noteInterestIndex[_noteID] = currentInterestIndex;

            return debt;
        }

        if (interestIndex < currentInterestIndex) {
            debt = debt.mulDivUp(currentInterestIndex, interestIndex);
            noteInterestIndex[_noteID] = currentInterestIndex;

            _noteDebtSnapshot[_noteID] = debt;
        }

        return debt;
    }

    function _accrueGlobalActiveInterest() internal returns (uint256) {
        (uint256 currentGlobalActiveInterestIndex, uint256 interestFactor) = _calculateInterestIndex();

        if (interestFactor > 0) {
            uint256 currentDebt = _activeDebtSnapshot;

            uint256 activeInterests = currentDebt.mulDivUp(interestFactor, INTEREST_PRECISION);

            _activeDebtSnapshot = currentDebt + activeInterests;

            claimableInterest += activeInterests;

            _lastInterestIndex = currentGlobalActiveInterestIndex;

            lastInterestIndexUpdate = block.timestamp;
        }

        return currentGlobalActiveInterestIndex;
    }

    function _calculateInterestIndex() internal view returns (uint256 currentInterestIndex, uint256 interestFactor) {
        uint256 lastIndexUpdateCached = lastInterestIndexUpdate;
        if (lastIndexUpdateCached == block.timestamp) {
            return (_lastInterestIndex, 0);
        }

        uint256 currentInterestRate = interestRate;

        currentInterestIndex = _lastInterestIndex;

        if (currentInterestRate > 0) {
            uint256 timeDelta = block.timestamp - lastIndexUpdateCached;

            interestFactor = timeDelta * currentInterestRate;

            currentInterestIndex += currentInterestIndex.mulDivUp(interestFactor, INTEREST_PRECISION);
        }
    }

    // ----------------- UPGRADABILITY ----------------- //
    /// @dev UUPS upgrade authorization - only owner can upgrade
    function _authorizeUpgrade(address) internal view override onlyOwner {}

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
