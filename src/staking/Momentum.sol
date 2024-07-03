// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC721Enumerable} from "forge-std/interfaces/IERC721.sol";

import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IVault} from "../interfaces/IVault.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

struct NoteMomentumData {
    // uint40 supports 34,000 years before overflow
    uint40 lastAction;
    // uint96 max is 79b at 18 decimals which is more than total kero supply
    uint96 keroseneDeposited;
    // uint120 supports deposit of entire kerosene supply by a single note for ~42 years before overflow
    uint120 lastMomentum;
}

contract Momentum is IERC20 {
    error TransferNotAllowed();
    error NotVaultManager();

    IVaultManager public immutable VAULT_MANAGER;
    IERC721Enumerable public immutable DNFT;
    IVault public immutable KEROSENE_VAULT;
    ERC20 public immutable KEROSENE;

    string public constant name = "Kerosene Momentum";
    string public constant symbol = "kMOM";
    uint8 public constant decimals = 18;

    uint40 globalLastUpdate;
    uint192 globalLastMomentum;

    mapping(uint256 => NoteMomentumData) public noteData;

    constructor(address vaultManager, address keroseneVault, address dnft) {
        VAULT_MANAGER = IVaultManager(vaultManager);
        DNFT = IERC721Enumerable(dnft);
        KEROSENE_VAULT = IVault(keroseneVault);
        KEROSENE = ERC20(KEROSENE_VAULT.asset());

        globalLastUpdate = uint40(block.timestamp);
        uint256 dnftSupply = DNFT.totalSupply();

        for (uint256 i = 0; i < dnftSupply; ++i) {
            uint256 depositedKero = KEROSENE_VAULT.id2asset(i);
            if (depositedKero == 0) {
                continue;
            }
            noteData[i] = NoteMomentumData({
                lastAction: uint40(block.timestamp),
                keroseneDeposited: uint96(depositedKero),
                lastMomentum: uint120(0)
            });
        }
    }

    /// @notice Returns the amount of tokens in existence.
    function totalSupply() external view returns (uint256) {
        // TODO - I don't think this logic is right.
        // should be last global MOMENTUM + (time elapsed * kerosene in vault)?
        // invariant, total supply should equal sum of all note amounts but looping through
        // all notes is expensive from a gas perspective especially as the number of notes grows
        // unbounded over time.
        uint256 timeElapsed = block.timestamp - globalLastUpdate;
        return  globalLastMomentum + uint192(timeElapsed * 1e18);
    }

    /// @notice Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external view returns (uint256) {
        uint256 totalMomentum;
        uint256 noteBalance = DNFT.balanceOf(account);

        uint256 totalKeroseneInVault = KEROSENE.balanceOf(
            address(KEROSENE_VAULT)
        );

        for (uint256 i = 0; i < noteBalance; i++) {
            uint256 noteId = DNFT.tokenOfOwnerByIndex(account, i);
            NoteMomentumData memory lastUpdate = noteData[noteId];
            totalMomentum += _computeMomentum(totalKeroseneInVault, lastUpdate);
        }

        return totalMomentum;
    }

    function balanceOfNote(uint256 noteId) external view returns (uint256) {
        uint256 totalKeroseneInVault = KEROSENE.balanceOf(
            address(KEROSENE_VAULT)
        );
        NoteMomentumData memory lastUpdate = noteData[noteId];
        return _computeMomentum(totalKeroseneInVault, lastUpdate);
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
        revert TransferNotAllowed();
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

    function afterKeroseneDeposited(uint256 noteId) external {
        if (msg.sender != address(VAULT_MANAGER)) {
            revert NotVaultManager();
        }

        NoteMomentumData memory lastUpdate = noteData[noteId];
        uint256 totalKeroseneInVault = KEROSENE.balanceOf(
            address(KEROSENE_VAULT)
        );

        uint256 newMomentum = _computeMomentum(
            totalKeroseneInVault,
            lastUpdate
        );

        noteData[noteId] = NoteMomentumData({
            lastAction: uint40(block.timestamp),
            keroseneDeposited: uint96(KEROSENE_VAULT.id2asset(noteId)),
            lastMomentum: uint120(newMomentum)
        });

        globalLastMomentum += uint192((globalLastUpdate - block.timestamp) * 1e18);
        globalLastUpdate = uint40(block.timestamp);

        emit Transfer(
            address(0),
            address(DNFT.ownerOf(noteId)),
            newMomentum - lastUpdate.lastMomentum
        );
    }

    function beforeKeroseneWithdrawn(
        uint256 noteId,
        uint256 amountWithdrawn
    ) external {
        if (msg.sender != address(VAULT_MANAGER)) {
            revert NotVaultManager();
        }

        NoteMomentumData memory lastUpdate = noteData[noteId];
        uint256 totalKeroseneInVault = KEROSENE.balanceOf(
            address(KEROSENE_VAULT)
        );
        uint256 momentum = _computeMomentum(
            totalKeroseneInVault,
            noteData[noteId]
        );

        uint256 slash = (amountWithdrawn * 1e18) / lastUpdate.keroseneDeposited;
        uint256 slashedMomentum = (slash * momentum) / 1e18;
        uint256 updatedMomentum = momentum - slashedMomentum;

        noteData[noteId] = NoteMomentumData({
            lastAction: uint40(block.timestamp),
            keroseneDeposited: uint96(
                lastUpdate.keroseneDeposited - amountWithdrawn
            ),
            lastMomentum: uint120(updatedMomentum)
        });

        globalLastMomentum += uint192((globalLastUpdate - block.timestamp) * 1e18);
        globalLastUpdate = uint40(block.timestamp);
    }

    function _computeMomentum(
        uint256 totalKeroseneInVault,
        NoteMomentumData memory lastUpdate
    ) internal view returns (uint256) {
        uint256 userShare = FixedPointMathLib.divWadUp(lastUpdate.keroseneDeposited, totalKeroseneInVault);
        uint256 timePassed = block.timestamp - lastUpdate.lastAction;
        uint256 momentumAccrued = timePassed * userShare;

        return lastUpdate.lastMomentum + momentumAccrued;
    }
}
