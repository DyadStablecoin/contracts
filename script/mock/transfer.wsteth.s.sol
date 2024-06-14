// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";


contract Transfer is Script {

  address TOKEN     = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address RECIPIENT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  uint    AMOUNT    = 200e18;

  function run() public {

    ERC20 token = ERC20(0xf3768D6e78E65FC64b8F12ffc824452130BD5394);

    vm.startBroadcast();  // ----------------------

    token.approve(0x987Aa6E80e995d6A76C4d061eE324fc760Ea9F61, 100000e18);
    // token.transfer(RECIPIENT, AMOUNT);

    vm.stopBroadcast();  // ----------------------------

    console.log("balance of recipient", token.balanceOf(RECIPIENT));
  }
}
