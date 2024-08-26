// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC721Enumerable} from "forge-std/interfaces/IERC721.sol";

import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IVault} from "../interfaces/IVault.sol";
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

    string public constant name = "Dyad XP";
    string public constant symbol = "dXP";
    uint8 public constant decimals = 18;

    uint40 globalLastUpdate;
    uint192 globalLastXP;
    uint256 totalKeroseneInVault;

    mapping(uint256 => NoteXPData) public noteData;

    uint40 public halvingCadence;
    uint40 public halvingStart;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address vaultManager, address keroseneVault, address dnft) {
        VAULT_MANAGER = IVaultManager(vaultManager);
        DNFT = IERC721Enumerable(dnft);
        KEROSENE_VAULT = IVault(keroseneVault);
        KEROSENE = ERC20(KEROSENE_VAULT.asset());
        _disableInitializers();
    }

    function initialize() 
      public 
        reinitializer(2) 
    {
      __UUPSUpgradeable_init();
      __Ownable_init(msg.sender);
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
        _updateNoteBalance(noteId, amountDeposited);
    }

    function forceUpdateXPBalance(uint256 noteId) external {
        if (msg.sender != owner()) {
            if (msg.sender != DNFT.ownerOf(noteId)) {
                revert Unauthorized();
            }
        }
        
        _updateNoteBalance(noteId, 0);
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
            keroseneDeposited: uint96(
                lastUpdate.keroseneDeposited - amountWithdrawn
            ),
            lastXP: uint120(xp - slashedXP)
        });

        globalLastXP = uint192(
            globalLastXP +
                (block.timestamp - globalLastUpdate) *
                totalKeroseneInVault -
                slashedXP
        );
        globalLastUpdate = uint40(block.timestamp);
        totalKeroseneInVault -= amountWithdrawn;

        emit Transfer(
            address(0),
            address(DNFT.ownerOf(noteId)),
            xp - lastUpdate.lastXP
        );
        emit Transfer(DNFT.ownerOf(noteId), address(0), slashedXP);
    }

    function setHalvingConfiguration(uint40 _halvingStart, uint40 _halvingCadence) external onlyOwner {
        if (halvingStart != 0) {
            uint256 dnftSupply = DNFT.totalSupply();
            for (uint256 i = 0; i < dnftSupply; ++i) {
                _updateNoteBalance(i, 0);
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

    function _authorizeUpgrade(
        address
    ) internal view override onlyOwner {}

    function _updateNoteBalance(uint256 noteId, uint256 amount) internal {
        NoteXPData memory lastUpdate = noteData[noteId];

        uint256 newXP = _computeXP(lastUpdate);

        totalKeroseneInVault += amount;

        noteData[noteId] = NoteXPData({
            lastAction: uint40(block.timestamp),
            keroseneDeposited: uint96(KEROSENE_VAULT.id2asset(noteId)),
            lastXP: uint120(newXP)
        });

        globalLastXP += uint192(
            (block.timestamp - globalLastUpdate) * (totalKeroseneInVault - amount)
        );
        globalLastUpdate = uint40(block.timestamp);

        if (newXP > lastUpdate.lastXP) {
            emit Transfer(
                address(0),
                address(DNFT.ownerOf(noteId)),
                newXP - lastUpdate.lastXP
            );
        } else {
            emit Transfer(
                address(DNFT.ownerOf(noteId)),
                address(0),
                lastUpdate.lastXP - newXP
            );
        }
    }

    function _computeXP(
        NoteXPData memory lastUpdate
    ) internal view returns (uint256) {
        uint256 elapsed = block.timestamp - lastUpdate.lastAction;
        uint256 halvings = (block.timestamp - halvingStart) / halvingCadence;
        uint256 deposited = lastUpdate.keroseneDeposited;

        return uint256(lastUpdate.lastXP + elapsed * deposited) >> halvings;
    }
}

