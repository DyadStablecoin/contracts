// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {VaultManagerV3} from "../../src/core/VaultManagerV3.sol";
import {DNft}           from "../../src/core/DNft.sol";
import {Dyad}           from "../../src/core/Dyad.sol";
import {VaultLicenser}  from "../../src/core/VaultLicenser.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployVaultManagerV3 is Script {
  function run() public {
    vm.startBroadcast();  // ----------------------

    Upgrades.upgradeProxy(
      0xb62bdb1a6ac97a9b70957dd35357311e8859f0d7,
      "VaultManagerV3.sol",
      abi.encodeCall(
        VaultManagerV3.initialize,
        (
          DNft(0xDc400bBe0B8B79C07A962EA99a642F5819e3b712),
          Dyad(0xfd03723a9a3abe0562451496a9a394d2c4bad4ab),
          VaultLicenser(0xfe81952a0a2c6ab603ef1b3cc69e1b6bffa92697)
        )
      )
    );

    vm.stopBroadcast();  // ----------------------------
  }
}


