// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DNft} from "./DNft.sol";
import {Dyad} from "./Dyad.sol";
import {VaultLicenser} from "./VaultLicenser.sol";
import {Vault} from "./Vault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract VaultManagerV2 is IVaultManager, UUPSUpgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    uint256 public constant MAX_VAULTS = 6;
    uint256 public constant MIN_COLLAT_RATIO = 1.5e18; // 150% // Collaterization
    uint256 public constant LIQUIDATION_REWARD = 0.2e18; //  20%

    DNft public dNft;
    Dyad public dyad;
    VaultLicenser public vaultLicenser;

    mapping(uint256 => EnumerableSet.AddressSet) internal vaults;
    mapping(uint256 /* id */ => uint256 /* block */) public lastDeposit;

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

    function initialize(DNft _dNft, Dyad _dyad, VaultLicenser _vaultLicenser) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);

        dNft = _dNft;
        dyad = _dyad;
        vaultLicenser = _vaultLicenser;
    }

    function add(uint256 id, address vault) external isDNftOwner(id) {
        if (!vaultLicenser.isLicensed(vault)) revert VaultNotLicensed();
        if (vaults[id].length() >= MAX_VAULTS) revert TooManyVaults();
        if (!vaults[id].add(vault)) revert VaultAlreadyAdded();
        emit Added(id, vault);
    }

    function remove(uint256 id, address vault) external isDNftOwner(id) {
        if (Vault(vault).id2asset(id) > 0) revert VaultHasAssets();
        if (!vaults[id].remove(vault)) revert VaultNotAdded();
        emit Removed(id, vault);
    }

    function deposit(uint256 id, address vault, uint256 amount) external isDNftOwner(id) {
        lastDeposit[id] = block.number;
        Vault _vault = Vault(vault);
        _vault.asset().safeTransferFrom(msg.sender, vault, amount);
        _vault.deposit(id, amount);
    }

    function withdraw(uint256 id, address vault, uint256 amount, address to) public isDNftOwner(id) {
        if (lastDeposit[id] == block.number) revert CanNotWithdrawInSameBlock();
        Vault(vault).withdraw(id, to, amount); // changes `exo` or `kero` value and `cr`
        _checkExoValueAndCollatRatio(id);
    }

    function mintDyad(uint256 id, uint256 amount, address to) external isDNftOwner(id) {
        dyad.mint(id, to, amount); // changes `mintedDyad` and `cr`
        _checkExoValueAndCollatRatio(id);
        emit MintDyad(id, amount, to);
    }

    function _checkExoValueAndCollatRatio(uint256 id) internal view {
        (uint256 exoValue, uint256 keroValue) = getVaultsValues(id);
        uint256 mintedDyad = dyad.mintedDyad(id);
        if (exoValue < mintedDyad) revert NotEnoughExoCollat();
        uint256 cr = _collatRatio(mintedDyad, exoValue + keroValue);
        if (cr < MIN_COLLAT_RATIO) revert CrTooLow();
    }

    function burnDyad(uint256 id, uint256 amount) public isDNftOwner(id) {
        dyad.burn(id, msg.sender, amount);
        emit BurnDyad(id, amount, msg.sender);
    }

    function redeemDyad(uint256 id, address vault, uint256 amount, address to)
        external
        isDNftOwner(id)
        returns (uint256)
    {
        burnDyad(id, amount);
        Vault _vault = Vault(vault);
        uint256 asset =
            amount * (10 ** (_vault.oracle().decimals() + _vault.asset().decimals())) / _vault.assetPrice() / 1e18;
        withdraw(id, vault, asset, to);
        emit RedeemDyad(id, vault, amount, to);
        return asset;
    }

    function liquidate(uint256 id, uint256 to, uint256 amount) external isValidDNft(id) isValidDNft(to) {
        if (collatRatio(id) >= MIN_COLLAT_RATIO) revert CrTooHigh();
        uint256 debt = dyad.mintedDyad(id);
        dyad.burn(id, msg.sender, amount); // changes `debt` and `cr`

        lastDeposit[to] = block.number; // `move` acts like a deposit

        uint256 totalValue = getTotalValue(id);
        uint256 reward_rate = amount.divWadDown(debt).mulWadDown(LIQUIDATION_REWARD);

        uint256 numberOfVaults = vaults[id].length();
        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault vault = Vault(vaults[id].at(i));
            uint256 value = vault.getUsdValue(id);
            uint256 share = value.divWadDown(totalValue);
            uint256 amountShare = share.mulWadDown(amount);
            uint256 valueToMove = amountShare + amountShare.mulWadDown(reward_rate);
            uint256 cappedValue = valueToMove > value ? value : valueToMove;
            uint256 asset =
                cappedValue * (10 ** (vault.oracle().decimals() + vault.asset().decimals())) / vault.assetPrice() / 1e18;

            vault.move(id, to, asset);
        }

        emit Liquidate(id, msg.sender, to);
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

    // ----------------- UPGRADABILITY ----------------- //
    function _authorizeUpgrade(address newImplementation) internal override {
        if (msg.sender != owner()) revert NotOwner();
    }
}
