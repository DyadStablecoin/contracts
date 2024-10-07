// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {VaultManagerV5} from "../../src/core/VaultManagerV5.sol";

contract DeployVaultManagerV3 is Script {
  function run() public {
    vm.startBroadcast();  // ----------------------

    VaultManagerV5 vm3 = new VaultManagerV5();

    vm.stopBroadcast();  // ----------------------------
  }
}

