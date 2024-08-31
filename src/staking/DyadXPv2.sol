// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC721Enumerable} from "forge-std/interfaces/IERC721.sol";

import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IVault} from "../interfaces/IVault.sol";
import {Dyad} from "../core/Dyad.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

struct NoteXPData {
    // uint40 supports 34,000 years before overflow
    uint40 lastAction;
    // uint96 max is 79b at 18 decimals which is more than total kero supply
    uint96 keroseneDeposited;
    // uint120 supports deposit of entire kerosene supply by a single note for ~42 years before overflow
    uint120 lastXP;
    // dyad minted
    uint96 dyadMinted;
}

/// @custom:oz-upgrades-from src/staking/DyadXP.sol:DyadXP
contract DyadXPv2 is IERC20, UUPSUpgradeable, OwnableUpgradeable {
    using FixedPointMathLib for uint256;

    error Unauthorized();
    error TransferNotAllowed();
    error ApproveNotAllowed();
    error NotVaultManager();
    error InvalidConfiguration();

    IVaultManager public immutable VAULT_MANAGER;
    IERC721Enumerable public immutable DNFT;
    IVault public immutable KEROSENE_VAULT;
    ERC20 public immutable KEROSENE;
    Dyad public immutable DYAD;

    string public constant name = "Dyad XP";
    string public constant symbol = "dXP";
    uint8 public constant decimals = 18;

    uint40 private globalLastUpdate; // unused
    uint192 private globalLastXP; // unused
    uint256 private totalKeroseneInVault; // unused

    mapping(uint256 => NoteXPData) public noteData;

    uint40 public halvingCadence;
    uint40 public halvingStart;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address vaultManager,
        address keroseneVault,
        address dnft,
        address dyad
    ) {
        VAULT_MANAGER = IVaultManager(vaultManager);
        DNFT = IERC721Enumerable(dnft);
        KEROSENE_VAULT = IVault(keroseneVault);
        KEROSENE = ERC20(KEROSENE_VAULT.asset());
        DYAD = Dyad(dyad);
        _disableInitializers();
    }

    function initialize() public reinitializer(2) {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);

        uint256 dnftSupply = DNFT.totalSupply();
        for (uint256 i; i < dnftSupply; ++i) {
            if (DYAD.mintedDyad(i) == 0) {
                continue;
            }
            _updateNoteBalanceForDyad(i);
        }
    }

    /// @notice Returns the amount of tokens in existence.
    function totalSupply() public view returns (uint256) {
        uint256 dnftSupply = DNFT.totalSupply();
        uint256 supply;
        for (uint256 i = 0; i < dnftSupply; ++i) {
            uint256 depositedKero = KEROSENE_VAULT.id2asset(i);
            if (depositedKero == 0) {
                continue;
            }
            NoteXPData memory lastUpdate = noteData[i];
            supply += _computeXP(lastUpdate);
        }
        return supply;
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

    function afterKeroseneDeposited(
        uint256 noteId,
        uint256 amountDeposited
    ) external {
        if (msg.sender != address(VAULT_MANAGER)) {
            revert NotVaultManager();
        }
        _updateNoteBalance(noteId);
    }

    function afterDyadMinted(uint256 noteId) external {
        if (msg.sender != address(VAULT_MANAGER)) {
            revert NotVaultManager();
        }
        _updateNoteBalanceForDyad(noteId);
    }

    function afterDyadBurned(uint256 noteId) external {
        if (msg.sender != address(VAULT_MANAGER)) {
            revert NotVaultManager();
        }
        _updateNoteBalanceForDyad(noteId);
    }

    function forceUpdateXPBalance(uint256 noteId) external {
        if (msg.sender != owner()) {
            if (msg.sender != DNFT.ownerOf(noteId)) {
                revert Unauthorized();
            }
        }
        _updateNoteBalance(noteId);
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
        uint120 newXP = uint120(xp - slashedXP);

        noteData[noteId] = NoteXPData({
            lastAction: uint40(block.timestamp),
            keroseneDeposited: uint96(
                lastUpdate.keroseneDeposited - amountWithdrawn
            ),
            lastXP: newXP,
            dyadMinted: lastUpdate.dyadMinted
        });

        _emitTransfer(DNFT.ownerOf(noteId), lastUpdate.lastXP, newXP);
    }

    function setHalvingConfiguration(
        uint40 _halvingStart,
        uint40 _halvingCadence
    ) external onlyOwner {
        if (halvingStart != 0) {
            uint256 dnftSupply = DNFT.totalSupply();
            for (uint256 i = 0; i < dnftSupply; ++i) {
                _updateNoteBalance(i);
            }
        } else if (_halvingStart < halvingStart) {
            revert InvalidConfiguration();
        } else if (_halvingStart < block.timestamp) {
            revert InvalidConfiguration();
        }
        if (_halvingCadence == 0) {
            revert InvalidConfiguration();
        }

        halvingStart = _halvingStart;
        halvingCadence = _halvingCadence;
    }

    function accrualRate(uint256 noteId) external view returns (uint256) {
        NoteXPData memory lastUpdate = noteData[noteId];

        return
            _computeAccrualRate(
                lastUpdate.keroseneDeposited,
                lastUpdate.dyadMinted
            );
    }

    function _authorizeUpgrade(address) internal view override onlyOwner {}

    function _updateNoteBalance(uint256 noteId) internal {
        NoteXPData memory lastUpdate = noteData[noteId];

        uint256 newXP = _computeXP(lastUpdate);

        noteData[noteId] = NoteXPData({
            lastAction: uint40(block.timestamp),
            keroseneDeposited: uint96(KEROSENE_VAULT.id2asset(noteId)),
            lastXP: uint120(newXP),
            dyadMinted: lastUpdate.dyadMinted
        });

        _emitTransfer(DNFT.ownerOf(noteId), lastUpdate.lastXP, newXP);
    }

    function _updateNoteBalanceForDyad(uint256 noteId) internal {
        NoteXPData memory lastUpdate = noteData[noteId];

        uint256 newXP = _computeXP(lastUpdate);

        noteData[noteId] = NoteXPData({
            lastAction: uint40(block.timestamp),
            keroseneDeposited: lastUpdate.keroseneDeposited,
            lastXP: uint120(newXP),
            dyadMinted: uint96(DYAD.mintedDyad(noteId))
        });

        _emitTransfer(DNFT.ownerOf(noteId), lastUpdate.lastXP, newXP);
    }

    function _emitTransfer(
        address user,
        uint256 oldBalance,
        uint256 newBalance
    ) internal {
        if (newBalance > oldBalance) {
            emit Transfer(address(0), user, newBalance - oldBalance);
        } else {
            emit Transfer(user, address(0), oldBalance - newBalance);
        }
    }

    function _computeXP(
        NoteXPData memory lastUpdate
    ) internal view returns (uint256) {
        uint256 rate = _computeAccrualRate(
            lastUpdate.keroseneDeposited,
            lastUpdate.dyadMinted
        );

        if (halvingCadence > 0) {
            uint256 start = halvingStart;
            if (start < block.timestamp) {
                uint256 halvings = ((block.timestamp - start) / halvingCadence);
                // if the last action was before the start of halvings, catch it up
                if (lastUpdate.lastAction < start) {
                    lastUpdate.lastXP += uint120((start - lastUpdate.lastAction) * rate);
                    lastUpdate.lastAction = uint40(start);
                }

                // get the start of the last halving period
                uint256 mostRecentHalvingStart = start + halvings * halvingCadence;

                if (lastUpdate.lastAction < mostRecentHalvingStart) {
                    // catch up the XP accrual to the most recent halving after the last action
                    uint256 halvingsAlreadyProcessed = (lastUpdate.lastAction - start) / halvingCadence;
                    uint256 nextHalving = start + (halvingsAlreadyProcessed + 1) * halvingCadence;

                    // catch up the XP accrual to the instant of the next halving;
                    // we can skip any subsequent periods in between because the net accrual during a
                    // full halving period is zero if there are no changes.
                    if (nextHalving < mostRecentHalvingStart) {
                        lastUpdate.lastXP += uint120((nextHalving - lastUpdate.lastAction) * rate);
                        lastUpdate.lastAction = uint40(mostRecentHalvingStart);
                    }

                    // compute the accrual for a single halving
                    lastUpdate.lastXP = uint120(lastUpdate.lastXP + (mostRecentHalvingStart - lastUpdate.lastAction) * rate >> 1);
                    lastUpdate.lastAction = uint40(mostRecentHalvingStart);
                }
            }
        }

        uint256 elapsed = block.timestamp - lastUpdate.lastAction;

        return uint256(lastUpdate.lastXP + elapsed * rate);
    }

    function _computeAccrualRate(
        uint256 keroDeposited,
        uint256 dyadMinted
    ) internal pure returns (uint256) {
        uint256 boost;
        if (keroDeposited > 0) {
            // boost = kerosene * (dyad / (dyad + kerosene))
            boost = keroDeposited.mulWadDown(
                dyadMinted.divWadDown(dyadMinted + keroDeposited)
            );
        }

        return keroDeposited + boost;
    }
}
