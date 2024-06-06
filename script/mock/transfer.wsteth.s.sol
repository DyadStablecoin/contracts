// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";


contract Transfer is Script {

  address TOKEN     = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address RECIPIENT = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
  uint    AMOUNT    = 200e18;

  function run() public {
    ERC20 token = ERC20(TOKEN);
    console.log("sender", msg.sender);
    console.log("balance of sender", token.balanceOf(msg.sender));

    vm.startBroadcast();  // ----------------------
    token.transfer(RECIPIENT, AMOUNT);
    vm.stopBroadcast();  // ----------------------------

    console.log("balance of recipient", token.balanceOf(RECIPIENT));
  }
}
