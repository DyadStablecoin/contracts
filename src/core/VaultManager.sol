// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DNft} from "./DNft.sol";
import {Dyad} from "./Dyad.sol";
import {Licenser} from "./Licenser.sol";
import {Vault} from "./Vault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract VaultManager is IVaultManager {
    using EnumerableSet for EnumerableSet.AddressSet;
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    uint256 public constant MAX_VAULTS = 5;
    uint256 public constant MIN_COLLATERIZATION_RATIO = 1.5e18; // 150%
    uint256 public constant LIQUIDATION_REWARD = 0.2e18; //  20%

    DNft public immutable dNft;
    Dyad public immutable dyad;
    Licenser public immutable vaultLicenser;

    mapping(uint256 => EnumerableSet.AddressSet) internal vaults;

    modifier isDNftOwner(uint256 id) {
        if (dNft.ownerOf(id) != msg.sender) revert NotOwner();
        _;
    }

    modifier isValidDNft(uint256 id) {
        if (dNft.ownerOf(id) == address(0)) revert InvalidDNft();
        _;
    }

    modifier isLicensed(address vault) {
        if (!vaultLicenser.isLicensed(vault)) revert NotLicensed();
        _;
    }

    constructor(DNft _dNft, Dyad _dyad, Licenser _licenser) {
        dNft = _dNft;
        dyad = _dyad;
        vaultLicenser = _licenser;
    }

    function add(uint256 id, address vault) external isDNftOwner(id) {
        if (vaults[id].length() >= MAX_VAULTS) revert TooManyVaults();
        if (!vaultLicenser.isLicensed(vault)) revert VaultNotLicensed();
        if (!vaults[id].add(vault)) revert VaultAlreadyAdded();
        emit Added(id, vault);
    }

    function remove(uint256 id, address vault) external isDNftOwner(id) {
        if (Vault(vault).id2asset(id) > 0) revert VaultHasAssets();
        if (!vaults[id].remove(vault)) revert VaultNotAdded();
        emit Removed(id, vault);
    }

    function deposit(uint256 id, address vault, uint256 amount) external isValidDNft(id) {
        Vault _vault = Vault(vault);
        _vault.asset().safeTransferFrom(msg.sender, address(vault), amount);
        _vault.deposit(id, amount);
    }

    function withdraw(uint256 id, address vault, uint256 amount, address to) public isDNftOwner(id) {
        Vault(vault).withdraw(id, to, amount);
        if (collatRatio(id) < MIN_COLLATERIZATION_RATIO) revert CrTooLow();
    }

    function mintDyad(uint256 id, uint256 amount, address to) external isDNftOwner(id) {
        dyad.mint(id, to, amount);
        if (collatRatio(id) < MIN_COLLATERIZATION_RATIO) revert CrTooLow();
        emit MintDyad(id, amount, to);
    }

    function burnDyad(uint256 id, uint256 amount) external isValidDNft(id) {
        dyad.burn(id, msg.sender, amount);
        emit BurnDyad(id, amount, msg.sender);
    }

    function redeemDyad(uint256 id, address vault, uint256 amount, address to)
        external
        isDNftOwner(id)
        returns (uint256)
    {
        dyad.burn(id, msg.sender, amount);
        Vault _vault = Vault(vault);
        uint256 asset =
            amount * (10 ** (_vault.oracle().decimals() + _vault.asset().decimals())) / _vault.assetPrice() / 1e18;
        withdraw(id, vault, asset, to);
        emit RedeemDyad(id, vault, amount, to);
        return asset;
    }

    function liquidate(uint256 id, uint256 to) external isValidDNft(id) isValidDNft(to) {
        uint256 cr = collatRatio(id);
        if (cr >= MIN_COLLATERIZATION_RATIO) revert CrTooHigh();
        dyad.burn(id, msg.sender, dyad.mintedDyad(id));

        uint256 cappedCr = cr < 1e18 ? 1e18 : cr;
        uint256 liquidationEquityShare = (cappedCr - 1e18).mulWadDown(LIQUIDATION_REWARD);
        uint256 liquidationAssetShare = (liquidationEquityShare + 1e18).divWadDown(cappedCr);

        uint256 numberOfVaults = vaults[id].length();
        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault vault = Vault(vaults[id].at(i));
            uint256 collateral = vault.id2asset(id).mulWadUp(liquidationAssetShare);
            vault.move(id, to, collateral);
        }
        emit Liquidate(id, msg.sender, to);
    }

    function collatRatio(uint256 id) public view returns (uint256) {
        uint256 _dyad = dyad.mintedDyad(id);
        if (_dyad == 0) return type(uint256).max;
        return getTotalUsdValue(id).divWadDown(_dyad);
    }

    function getTotalUsdValue(uint256 id) public view returns (uint256) {
        uint256 totalUsdValue;
        uint256 numberOfVaults = vaults[id].length();
        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault vault = Vault(vaults[id].at(i));
            uint256 usdValue;
            if (vaultLicenser.isLicensed(address(vault))) {
                usdValue = vault.getUsdValue(id);
            }
            totalUsdValue += usdValue;
        }
        return totalUsdValue;
    }

    // ----------------- MISC ----------------- //

    function getVaults(uint256 id) external view returns (address[] memory) {
        return vaults[id].values();
    }

    function hasVault(uint256 id, address vault) external view returns (bool) {
        return vaults[id].contains(vault);
    }
}
