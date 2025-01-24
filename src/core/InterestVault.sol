// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Owned} from "@solmate/src/auth/Owned.sol";
import {Dyad} from "./Dyad.sol";

contract InterestVault is Owned {
    uint256 public constant NOTE_ID = type(uint256).max;

    address public immutable VAULT_MANAGER;
    Dyad public immutable DYAD;

    error OnlyVaultManager();

    constructor(address _owner, address _dyadAddress, address _vaultManager) Owned(_owner) {
        DYAD = Dyad(_dyadAddress);
        VAULT_MANAGER = _vaultManager;
    }

    function mintInterest(uint256 _amount) external {
        _onlyVaultManager();

        DYAD.mint(NOTE_ID, address(this), _amount);
    }

    function _onlyVaultManager() internal view {
        if (msg.sender != VAULT_MANAGER) {
            revert OnlyVaultManager();
        }
    }
}
