// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";


contract Transfer is Script {

  address TOKEN     = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address RECIPIENT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  uint    AMOUNT    = 200e18;

  function run() public {

    vm.startBroadcast();  // ----------------------

    ERC20 token = ERC20(TOKEN);
    token.transfer(RECIPIENT, AMOUNT);

    vm.stopBroadcast();  // ----------------------------

    console.log("balance of recipient", token.balanceOf(RECIPIENT));
  }
}
