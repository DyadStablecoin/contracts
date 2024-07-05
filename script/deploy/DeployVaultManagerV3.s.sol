// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {VaultManagerV3} from "../../src/core/VaultManagerV3.sol";
import {DNft}           from "../../src/core/DNft.sol";
import {Dyad}           from "../../src/core/Dyad.sol";
import {VaultLicenser}  from "../../src/core/VaultLicenser.sol";
import {Parameters}     from "../../src/params/Parameters.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployVaultManagerV3 is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    VaultManagerV3 vm3 = new VaultManagerV3();

    vm.stopBroadcast();  // ----------------------------
  }
}
