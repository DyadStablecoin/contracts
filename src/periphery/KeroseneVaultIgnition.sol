// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IExtension} from "../interfaces/IExtension.sol";
import {Ignition} from "../staking/Ignition.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IVaultManagerV5} from "../interfaces/IVaultManagerV5.sol";
import {DNft} from "../core/DNft.sol";

contract KeroseneVaultIgnition is IExtension {
    error NotOwner();

    Ignition public ignition;
    address public keroseneVault;
    IVaultManagerV5 public vaultManager;
    address public kerosene;
    DNft public dnft;

    constructor(address _ignition, address _keroseneVault, address _vaultManager, address _kerosene, address _dnft) {
        ignition = Ignition(_ignition);
        keroseneVault = _keroseneVault;
        vaultManager = IVaultManagerV5(_vaultManager);
        dnft = DNft(_dnft);

        IERC20(kerosene).approve(address(ignition), type(uint256).max);
    }

    function name() external view returns (string memory) {
        return "Kerosene Vault Ignition";
    }

    function description() external view returns (string memory) {
        return "This extension allows you to ignite kerosene from your vault.";
    }

    function getHookFlags() external view returns (uint256) {
        return 0;
    }

    function igniteKeroseneFromVault(uint256 id, uint256 amount) external {
        if (dnft.ownerOf(id) != msg.sender) {
            revert NotOwner();
        }
        vaultManager.withdraw(id, keroseneVault, amount, address(this));
        ignition.ignite(id, amount);
    }
}
