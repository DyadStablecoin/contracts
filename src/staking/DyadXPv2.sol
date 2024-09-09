// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC721Enumerable} from "forge-std/interfaces/IERC721.sol";

import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IVault} from "../interfaces/IVault.sol";
import {Dyad} from "../core/Dyad.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

struct NoteXPData {
    // uint40 supports 34,000 years before overflow
    uint40 lastAction;
    // uint96 max is 79b at 18 decimals which is more than total kero supply
    uint96 keroseneDeposited;
    // uint120 supports deposit of entire kerosene supply by a single note for ~42 years before overflow
    uint120 lastXP;
    // New field to store total XP earned by the note
    uint256 totalXP;
    // New field to store the amount of dyad minted for the note
    uint256 dyadMinted; // New field added
}

/// @custom:oz-upgrades-from src/staking/DyadXP.sol:DyadXP
contract DyadXPv2 is IERC20, UUPSUpgradeable, OwnableUpgradeable {
    using FixedPointMathLib for uint256;
    using Math for uint256;

    error TransferNotAllowed();
    error ApproveNotAllowed();
    error NotVaultManager();

    IVaultManager public immutable VAULT_MANAGER;
    IERC721Enumerable public immutable DNFT;
    IVault public immutable KEROSENE_VAULT;
    ERC20 public immutable KEROSENE;

    string public constant name = "Dyad XP";
    string public constant symbol = "dXP";
    uint8 public constant decimals = 18;

    uint40 globalLastUpdate;
    uint192 globalLastXP;
    uint256 totalKeroseneInVault;

    mapping(uint256 => NoteXPData) public noteData;

    Dyad public immutable DYAD;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address vaultManager, address keroseneVault, address dnft, address dyad) {
        VAULT_MANAGER = IVaultManager(vaultManager);
        DNFT = IERC721Enumerable(dnft);
        KEROSENE_VAULT = IVault(keroseneVault);
        KEROSENE = ERC20(KEROSENE_VAULT.asset());
        DYAD = Dyad(dyad);
        _disableInitializers();
    }

    function initialize(address owner) public reinitializer(2) {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);

        globalLastUpdate = uint40(block.timestamp);
        uint256 dnftSupply = DNFT.totalSupply();

        for (uint256 i = 0; i < dnftSupply; ++i) {
            uint256 depositedKero = KEROSENE_VAULT.id2asset(i);
            uint256 dyadMinted = DYAD.mintedDyad(i);
            noteData[i] = NoteXPData({
                lastAction: uint40(block.timestamp),
                keroseneDeposited: uint96(depositedKero),
                lastXP: noteData[i].lastXP,
                totalXP: noteData[i].totalXP,
                dyadMinted: dyadMinted
            });
        }
    }

    /// @notice Returns the amount of tokens in existence.
    function totalSupply() public view returns (uint256) {
        uint256 totalXP;
        for (uint256 i = 0; i < DNFT.totalSupply(); i++) {
            totalXP += _computeXP(noteData[i]);
        }
        return totalXP;
    }

    /// @notice Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external view returns (uint256) {
        uint256 totalXP;
        uint256 noteBalance = DNFT.balanceOf(account);

        for (uint256 i = 0; i < noteBalance; i++) {
            uint256 noteId = DNFT.tokenOfOwnerByIndex(account, i);
            NoteXPData memory lastUpdate = noteData[noteId];
            totalXP += _computeXP(lastUpdate);
        }

        return totalXP;
    }

    function balanceOfNote(uint256 noteId) external view returns (uint256) {
        NoteXPData memory lastUpdate = noteData[noteId];
        return _computeXP(lastUpdate);
    }

    /// @notice Moves `amount` tokens from the caller's account to `to`.
    function transfer(address, uint256) external pure returns (bool) {
        revert TransferNotAllowed();
    }

    /// @notice Returns the remaining number of tokens that `spender` is allowed
    /// to spend on behalf of `owner`
    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    /// @notice Sets `amount` as the allowance of `spender` over the caller's tokens.
    /// @dev Be aware of front-running risks: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function approve(address, uint256) external pure returns (bool) {
        revert ApproveNotAllowed();
    }

    /// @notice Moves `amount` tokens from `from` to `to` using the allowance mechanism.
    /// `amount` is then deducted from the caller's allowance.
    function transferFrom(
        address,
        address,
        uint256
    ) external pure returns (bool) {
        revert TransferNotAllowed();
    }

    function beforeKeroseneWithdrawn(
        uint256 noteId,
        uint256 amountWithdrawn
    ) external {
        if (msg.sender != address(VAULT_MANAGER)) {
            revert NotVaultManager();
        }

        NoteXPData memory lastUpdate = noteData[noteId];

        uint256 xp = _computeXP(lastUpdate);

        uint256 slashedXP = xp.mulDivUp(
            amountWithdrawn,
            lastUpdate.keroseneDeposited
        );

        if (slashedXP > xp) {
            slashedXP = xp;
        }       

        noteData[noteId] = NoteXPData({
            lastAction: uint40(block.timestamp),
            keroseneDeposited: uint96(lastUpdate.keroseneDeposited - amountWithdrawn),
            lastXP: uint120(xp - slashedXP),
            totalXP: lastUpdate.totalXP + slashedXP, 
            dyadMinted: DYAD.mintedDyad(noteId)
        });

        emit Transfer(
            address(0),
            address(DNFT.ownerOf(noteId)),
            xp - lastUpdate.lastXP
        );
        emit Transfer(DNFT.ownerOf(noteId), address(0), slashedXP);
    }

    function updateXP(uint256 noteId) external {
        if (msg.sender != address(VAULT_MANAGER)) {
            revert NotVaultManager();
        }

        NoteXPData memory lastUpdate = noteData[noteId];
        uint256 newXP = _computeXP(lastUpdate);

        noteData[noteId] = NoteXPData({
            lastAction: uint40(block.timestamp),
            keroseneDeposited: uint96(KEROSENE_VAULT.id2asset(noteId)),
            lastXP: uint120(newXP),
            totalXP: lastUpdate.totalXP, 
            dyadMinted: DYAD.mintedDyad(noteId)
        });

        if (newXP > lastUpdate.lastXP) {
            emit Transfer(address(0), DNFT.ownerOf(noteId), newXP - lastUpdate.lastXP );
        } else {
            emit Transfer(DNFT.ownerOf(noteId), address(0), lastUpdate.lastXP - newXP);
        }
    }

    function _authorizeUpgrade(
        address
    ) internal view override onlyOwner {}

    function _computeXP(
        NoteXPData memory lastUpdate
    ) internal view returns (uint256) {
        uint256 elapsed = block.timestamp - lastUpdate.lastAction;
        uint256 deposited = lastUpdate.keroseneDeposited;
        uint256 dyadMinted = lastUpdate.dyadMinted;

        uint256 totalXP = lastUpdate.totalXP;
        uint256 accrualRateModifier = totalXP > 0 ? 1e18 / totalXP.log10() : 1e18;

        uint256 adjustedAccrualRate = accrualRateModifier * 1e7;

        uint256 bonus = deposited;

        if (dyadMinted + deposited != 0) {
            bonus += deposited * dyadMinted / (dyadMinted + deposited);
        }

        return uint256(lastUpdate.lastXP + (elapsed * adjustedAccrualRate * bonus) / 1e18);
    }
}
