// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {VaultManagerV6} from "../../src/core/VaultManagerV6.sol";
import {Dyad} from "../../src/core/Dyad.sol";
import {KeroseneValuer} from "../../src/staking/KeroseneValuer.sol";
import {Parameters} from "../../src/params/Parameters.sol";
import {Kerosine} from "../../src/staking/Kerosine.sol";
import {KerosineManager} from "../../src/core/KerosineManager.sol";
import {InterestVault} from "../../src/core/InterestVault.sol";
import {VaultLicenser} from "../../src/core/VaultLicenser.sol";

contract DeployVaultManagerV6 is Script, Parameters {
    function run() public {
        vm.startBroadcast(); // ----------------------

        // Deploy new vault manager implementation
        VaultManagerV6 impl = new VaultManagerV6();

        KeroseneValuer keroseneValuer = new KeroseneValuer(
            Kerosine(MAINNET_KEROSENE), KerosineManager(MAINNET_V2_KEROSENE_MANAGER), Dyad(MAINNET_V2_DYAD)
        );

        InterestVault interestVault = new InterestVault(address(this), MAINNET_V2_DYAD, MAINNET_V2_VAULT_MANAGER);

        VaultManagerV6(MAINNET_V2_VAULT_MANAGER).upgradeToAndCall(
            address(impl),
            abi.encodeWithSelector(impl.initialize.selector, address(keroseneValuer), address(interestVault))
        );

        // After deployment these things need to happen

        // Dyad dyad = Dyad(MAINNET_V2_DYAD);
        // VaultManagerV6 manager = VaultManagerV6(MAINNET_V2_VAULT_MANAGER);
        // dyad.licenser().add(address(interestVault));

        vm.stopBroadcast(); // ----------------------------
    }
}
