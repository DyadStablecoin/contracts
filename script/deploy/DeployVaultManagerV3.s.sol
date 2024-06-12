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
      0xB62bdb1A6AC97A9B70957DD35357311e8859f0d7,
      "VaultManagerV3.sol",
      abi.encodeCall(
        VaultManagerV3.initialize,
        (
          DNft(0xDc400bBe0B8B79C07A962EA99a642F5819e3b712),
          Dyad(0xFd03723a9A3AbE0562451496a9a394D2C4bad4ab),
          VaultLicenser(0xFe81952A0a2c6ab603ef1B3cC69E1B6Bffa92697)
        )
      )
    );

    vm.stopBroadcast();  // ----------------------------
  }
}


