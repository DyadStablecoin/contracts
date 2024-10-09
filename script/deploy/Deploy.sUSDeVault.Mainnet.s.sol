// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {Parameters} from "../../src/params/Parameters.sol";
import {VaultStakedUSDe} from "../../src/core/Vault.sUSDe.sol";
import {VaultManager} from "../../src/core/VaultManager.sol";
import {DNft} from "../../src/core/DNft.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployStakedUSDeVault is Script, Parameters {
    function run() public {
        vm.startBroadcast(); // ----------------------

        new VaultStakedUSDe(
            MAINNET_OWNER,
            VaultManager(MAINNET_V2_VAULT_MANAGER),
            ERC20(MAINNET_SUSDE),
            IAggregatorV3(MAINNET_CHAINLINK_SUSDE),
            DNft(MAINNET_DNFT)
        );

        vm.stopBroadcast(); // ----------------------------
    }
}
