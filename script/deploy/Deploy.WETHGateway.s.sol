// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {Parameters} from "../../src/params/Parameters.sol";
import {WETHGateway} from "../../src/periphery/WETHGateway.sol";

contract DeployVault is Script, Parameters {
    function run() public {
        vm.startBroadcast(); // ----------------------

        new WETHGateway(MAINNET_V2_DYAD, MAINNET_DNFT, MAINNET_WETH, MAINNET_V2_VAULT_MANAGER, MAINNET_V2_WETH_VAULT);

        vm.stopBroadcast(); // ----------------------------
    }
}
