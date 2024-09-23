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
import "forge-std/console2.sol";

struct NoteXPData {
    // uint40 supports 34,000 years before overflow
    uint40 lastAction;
    // uint96 max is 79b at 18 decimals which is more than total kero supply
    uint96 accrualRate;
    // uint120 supports deposit of entire kerosene supply by a single note for ~42 years before overflow
    uint120 lastXP;
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

    uint40 private globalLastUpdate;
    uint192 private globalLastXP;
    uint256 private globalAccrualRate;

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

    function initialize(uint40 _halvingStart, uint40 _halvingCadence) public reinitializer(2) {
        uint256 dnftSupply = DNFT.totalSupply();
        for (uint256 i = 0; i < dnftSupply; ++i) {
            if (DYAD.mintedDyad(i) == 0) {
                continue;
            }
            _updateNoteBalance(i);
        }
        if (_halvingCadence == 0) {
            revert InvalidConfiguration();
        }
        if (_halvingStart < block.timestamp) {
            revert InvalidConfiguration();
        }
        halvingCadence = _halvingCadence;
        halvingStart = _halvingStart;
    }

    /// @notice Returns the amount of tokens in existence.
    function totalSupply() public view returns (uint256) {
        return _computeXP(globalAccrualRate, globalLastUpdate, globalLastXP);
    }

    /// @notice Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external view returns (uint256) {
        uint256 totalXP;
        uint256 noteBalance = DNFT.balanceOf(account);

        for (uint256 i = 0; i < noteBalance; i++) {
            uint256 noteId = DNFT.tokenOfOwnerByIndex(account, i);
            totalXP += balanceOfNote(noteId);
        }

        return totalXP;
    }

    function balanceOfNote(uint256 noteId) public view returns (uint256) {
        NoteXPData memory lastUpdate = noteData[noteId];
        return _computeXP(lastUpdate.accrualRate, lastUpdate.lastAction, lastUpdate.lastXP);
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

    function afterNoteUpdated(uint256 noteId) external {
      if (msg.sender != address(VAULT_MANAGER)) {
          revert NotVaultManager();
      }
      _updateNoteBalance(noteId);
    }

    function forceUpdateXPBalance(uint256 noteId) external onlyOwner {
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

        uint256 xp = _computeXP(lastUpdate.accrualRate, lastUpdate.lastAction, lastUpdate.lastXP);
        uint256 keroseneDeposited = KEROSENE_VAULT.id2asset(noteId);
        uint256 dyadMinted = DYAD.mintedDyad(noteId);

        uint256 slashedXP = xp.mulDivUp(
            amountWithdrawn,
            keroseneDeposited
        );
        if (slashedXP > xp) {
            slashedXP = xp;
        }
        uint120 newXP = uint120(xp - slashedXP);
        uint256 newAccrualRate = _computeAccrualRate(
            keroseneDeposited - amountWithdrawn,
            dyadMinted
        );

        noteData[noteId] = NoteXPData({
            lastAction: uint40(block.timestamp),
            accrualRate: uint96(newAccrualRate),
            lastXP: newXP
        });

        globalLastXP = uint192(totalSupply() - slashedXP);
        globalLastUpdate = uint40(block.timestamp);
        globalAccrualRate = globalAccrualRate - lastUpdate.accrualRate + newAccrualRate;

        _emitTransfer(DNFT.ownerOf(noteId), lastUpdate.lastXP, newXP);
    }

    function grantXP(uint256 noteId, uint256 amount) external {
        if (msg.sender != address(VAULT_MANAGER)) {
            revert NotVaultManager();
        }

        _updateNoteBalance(noteId);
        noteData[noteId].lastXP += uint120(amount);
        globalLastXP += amount;

        emit Transfer(address(0), DNFT.ownerOf(noteId), amount);
    }

    function accrualRate(uint256 noteId) external view returns (uint256) {
        NoteXPData memory lastUpdate = noteData[noteId];
        return lastUpdate.accrualRate;
    }

    function _authorizeUpgrade(address) internal view override onlyOwner {}

    function _updateNoteBalance(uint256 noteId) internal {
        NoteXPData memory lastUpdate = noteData[noteId];

        uint256 newXP = _computeXP(lastUpdate.accrualRate, lastUpdate.lastAction, lastUpdate.lastXP);

        uint256 keroseneDeposited = KEROSENE_VAULT.id2asset(noteId);
        uint256 dyadMinted = DYAD.mintedDyad(noteId);

        uint256 newAccrualRate = _computeAccrualRate(
            keroseneDeposited,
            dyadMinted
        );

        noteData[noteId] = NoteXPData({
            lastAction: uint40(block.timestamp),
            accrualRate: uint96(newAccrualRate),
            lastXP: uint120(newXP)
        });

        globalLastXP = uint192(totalSupply());
        globalLastUpdate = uint40(block.timestamp);
        globalAccrualRate = globalAccrualRate - lastUpdate.accrualRate + newAccrualRate;

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
        uint256 rate,
        uint256 lastUpdate,
        uint256 lastXP
    ) internal view returns (uint256) {
        if (halvingCadence > 0) {
            uint256 start = halvingStart;
            if (start < block.timestamp) {
                uint256 halvings = ((block.timestamp - start) / halvingCadence);
                // if the last action was before the start of halvings, catch it up
                if (lastUpdate < start) {
                    lastXP += uint120((start - lastUpdate) * rate);
                    lastUpdate = uint40(start);
                }
                // get the start of the last halving period
                uint256 mostRecentHalvingStart = start + halvings * halvingCadence;
                
                if (lastUpdate < mostRecentHalvingStart) {
                    
                    uint256 halvingsAlreadyProcessed = 1 + (lastUpdate - start) / halvingCadence;
                    uint256 _nextHalving = start + (halvingsAlreadyProcessed) * halvingCadence;

                    // catch up the XP balance to the first halving after the last action
                    if (_nextHalving <= mostRecentHalvingStart) {
                        uint256 elapsed = (_nextHalving - lastUpdate);
                        lastXP = uint120(lastXP + elapsed * rate >> 1);
                    }
                    
                    // if there are more halvings to process, process them
                    if (halvings > halvingsAlreadyProcessed) {
                        uint256 halvingsToProcess = halvings - halvingsAlreadyProcessed;
                        uint256 accrued = uint256(halvingCadence * rate).mulWadDown(1e18 - (1e18 >> halvingsToProcess));

                        // formula is (existing balance / 2^n) + (accrualPerHalving * (1 - (1 / 2^n)))
                        lastXP = uint120((lastXP >> halvingsToProcess) + accrued);
                    }
                    lastUpdate = uint40(mostRecentHalvingStart);
                }
            }
        }
        return uint256(lastXP + (block.timestamp - lastUpdate) * rate);
    }

    function nextHalving() public view returns (uint256) {
        if (halvingCadence == 0 || halvingStart == 0 || block.timestamp < halvingStart) {
            return 0; // Halving not configured or not started yet
        }

        uint256 elapsedTime = block.timestamp - halvingStart;
        uint256 completedHalvings = elapsedTime / halvingCadence;
        return halvingStart + (completedHalvings + 1) * halvingCadence;
    }

    function _computeAccrualRate(
        uint256 keroDeposited,
        uint256 dyadMinted
    ) internal pure returns (uint256) {
        if (keroDeposited == 0) {
            return 0;
        }

        uint256 boost;
        if (dyadMinted > 0) {
            boost = keroDeposited.mulWadDown(
                dyadMinted.divWadDown(dyadMinted + keroDeposited)
            );
        }

        return keroDeposited + boost;
    }
}
