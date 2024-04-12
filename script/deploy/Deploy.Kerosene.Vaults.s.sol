// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {Parameters} from "../../src/params/Parameters.sol";
import {KerosineManager}        from "../../src/core/KerosineManager.sol";
import {UnboundedKerosineVault} from "../../src/core/Vault.kerosine.unbounded.sol";
import {BoundedKerosineVault}   from "../../src/core/Vault.kerosine.bounded.sol";
import {VaultManager}           from "../../src/core/VaultManager.sol";
import {Dyad}                   from "../../src/core/Dyad.sol";
import {Kerosine}               from "../../src/staking/Kerosine.sol";
import {KerosineDenominator}    from "../../src/staking/KerosineDenominator.sol";
import {Staking}                from "../../src/staking/Staking.sol";

contract DeployKeroseneVaults is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    KerosineManager kerosineManager = new KerosineManager();

    kerosineManager.add(MAINNET_WETH_VAULT);
    kerosineManager.add(MAINNET_WSTETH_VAULT);

    kerosineManager.transferOwnership(MAINNET_OWNER);

    // IMPORTANT: Vault needs to be licensed!
    UnboundedKerosineVault unboundedKerosineVault = new UnboundedKerosineVault(
      VaultManager(MAINNET_VAULT_MANAGER),
      Kerosine(MAINNET_KEROSENE), 
      Dyad(MAINNET_DYAD),
      kerosineManager
    );

    // IMPORTANT: Vault needs to be licensed!
    BoundedKerosineVault boundedKerosineVault     = new BoundedKerosineVault(
      VaultManager(MAINNET_VAULT_MANAGER),
      Kerosine(MAINNET_KEROSENE), 
      kerosineManager
    );

    boundedKerosineVault.setUnboundedKerosineVault(unboundedKerosineVault);

    KerosineDenominator _kerosineDenominator = new KerosineDenominator(
      Kerosine(MAINNET_KEROSENE)
    );

    unboundedKerosineVault.setDenominator(_kerosineDenominator);

    vm.stopBroadcast();  // ----------------------------
  }
}
