// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {Parameters} from "../../src/params/Parameters.sol";
import {VaultWeETH} from "../../src/core/Vault.weETH.sol";
import {VaultManager} from "../../src/core/VaultManager.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";
import {IVault} from "../../src/interfaces/IVault.sol";
import {DNft} from "../../src/core/DNft.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployVault is Script, Parameters {
    function run() public {
        vm.startBroadcast(); // ----------------------

        new VaultWeETH(
            MAINNET_OWNER,
            VaultManager(MAINNET_V2_VAULT_MANAGER),
            ERC20(MAINNET_WEETH),
            IAggregatorV3(MAINNET_CHAINLINK_WEETH),
            IVault(MAINNET_V2_WETH_VAULT),
            DNft(MAINNET_DNFT)
        );

        vm.stopBroadcast(); // ----------------------------
    }
}
