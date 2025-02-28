// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {VaultManagerV7} from "../../src/core/VaultManagerV7.sol";
import {Parameters} from "../../src/params/Parameters.sol";

contract DeployVaultManagerV7 is Script, Parameters {
    function run() public {
        vm.startBroadcast(); // ----------------------

        // Deploy new vault manager implementation
        VaultManagerV7 impl = new VaultManagerV7();

        // Upgrade vault manager to V7
        // VaultManagerV7(MAINNET_V2_VAULT_MANAGER).upgradeToAndCall(
        //     address(impl),
        //     abi.encodeWithSelector(impl.initialize.selector, address(keroseneValuer), address(interestVault))
        // );

        vm.stopBroadcast(); // ----------------------------
    }
}
