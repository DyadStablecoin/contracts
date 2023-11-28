// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";

import {DNft} from "./DNft.sol";
import {Dyad} from "./Dyad.sol";
import {Licenser} from "./Licenser.sol";
import {Vault} from "./Vault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

contract VaultManager is IVaultManager {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    uint256 public constant MAX_VAULTS = 5;
    uint256 public constant MIN_COLLATERIZATION_RATIO = 15e17; // 150%

    DNft public immutable dNft;
    Dyad public immutable dyad;
    Licenser public immutable vaultLicenser;

    mapping(uint256 => address[]) public vaults;
    mapping(uint256 => mapping(address => bool)) public isDNftVault;

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
        if (vaults[id].length >= MAX_VAULTS) revert TooManyVaults();
        if (!vaultLicenser.isLicensed(vault)) revert VaultNotLicensed();
        if (isDNftVault[id][vault]) revert VaultAlreadyAdded();
        vaults[id].push(vault);
        isDNftVault[id][vault] = true;
        emit Added(id, vault);
    }

    function remove(uint256 id, address vault) external isDNftOwner(id) {
        if (Vault(vault).id2asset(id) > 0) revert VaultHasAssets();
        if (!isDNftVault[id][vault]) revert NotDNftVault();
        uint256 numberOfVaults = vaults[id].length;
        uint256 index;
        for (uint256 i = 0; i < numberOfVaults; i++) {
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
        uint256 asset = amount * (10 ** _vault.oracle().decimals()) / _vault.assetPrice();
        withdraw(id, vault, asset, to);
        emit RedeemDyad(id, vault, amount, to);
        return asset;
    }

    function liquidate(uint256 id, uint256 to) external isValidDNft(id) isValidDNft(to) {
        if (collatRatio(id) >= MIN_COLLATERIZATION_RATIO) revert CrTooHigh();
        uint256 mintedDyad = dyad.mintedDyad(address(this), id);
        dyad.burn(id, msg.sender, mintedDyad);

        uint256 numberOfVaults = vaults[id].length;
        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault(vaults[id][i]).moveAll(id, to);
        }
        emit Liquidate(id, msg.sender, to);
    }

    function collatRatio(uint256 id) public view returns (uint256) {
        uint256 _dyad = dyad.mintedDyad(address(this), id);
        if (_dyad == 0) return type(uint256).max;
        return getTotalUsdValue(id).divWadDown(_dyad);
    }

    function getTotalUsdValue(uint256 id) public view returns (uint256) {
        uint256 totalUsdValue;
        uint256 numberOfVaults = vaults[id].length;
        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault vault = Vault(vaults[id][i]);
            uint256 usdValue;
            if (vaultLicenser.isLicensed(address(vault))) {
                usdValue = vault.getUsdValue(id);
            }
            totalUsdValue += usdValue;
        }
        return totalUsdValue;
    }
}
