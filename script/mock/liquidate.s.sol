// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {VaultManagerV2} from "../../src/core/VaultManagerV2.sol";

contract Transfer is Script {

  address TOKEN     = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address RECIPIENT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  uint    AMOUNT    = 200e18;

  function run() public {

    vm.startBroadcast();  // ----------------------

    VaultManagerV2 vaultManager = VaultManagerV2(0xB62bdb1A6AC97A9B70957DD35357311e8859f0d7);

    vaultManager.liquidate(619, 364, 2250000000000000000000);

    vm.stopBroadcast();  // ----------------------------

  }
}
