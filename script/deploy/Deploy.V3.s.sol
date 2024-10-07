// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {Parameters} from "../../src/params/Parameters.sol";
import {VaultManagerV3} from "../../src/core/VaultManagerV3.sol";
import {DNft} from "../../src/core/DNft.sol";
import {Dyad} from "../../src/core/Dyad.sol";
import {VaultLicenser} from "../../src/core/VaultLicenser.sol";
import {Licenser} from "../../src/core/Licenser.sol";
import {Vault} from "../../src/core/Vault.sol";
import {VaultWstEth} from "../../src/core/Vault.wsteth.sol";
import {IWETH} from "../../src/interfaces/IWETH.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";
import {KerosineManager} from "../../src/core/KerosineManager.sol";
import {KeroseneOracle} from "../../src/core/KeroseneOracle.sol";
import {KeroseneVault} from "../../src/core/VaultKerosene.sol";
import {Kerosine} from "../../src/staking/Kerosine.sol";
import {KerosineDenominator} from "../../src/staking/KerosineDenominator.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

struct Contracts {
    DNft dNft;
    Dyad dyad;
    VaultManagerV3 vaultManager;
    Vault ethVault;
    VaultWstEth wstEth;
    KeroseneVault keroseneVault;
}

/**
 * Notice:
 * V2 deploys all contracts except for the DNft contract.
 */
contract DeployV3 is Script, Parameters {
    function run() public returns (Contracts memory) {
        vm.startPrank(MAINNET_OWNER);
        Upgrades.upgradeProxy(
            MAINNET_V2_VAULT_MANAGER, "VaultManagerV3.sol", abi.encodeCall(VaultManagerV3.initialize, ())
        );
        vm.stopPrank();

        VaultManagerV3 vaultManager = VaultManagerV3(MAINNET_V2_VAULT_MANAGER);

        return Contracts(
            DNft(MAINNET_DNFT),
            Dyad(MAINNET_V2_DYAD),
            vaultManager,
            Vault(MAINNET_V2_WETH_VAULT),
            VaultWstEth(MAINNET_V2_WSTETH_VAULT),
            KeroseneVault(MAINNET_V2_KEROSENE_V2_VAULT)
        );
    }
}
