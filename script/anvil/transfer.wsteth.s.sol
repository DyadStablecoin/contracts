// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract Read is Script {
  function run() public {
    address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address holder = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;
    address recipient = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint amount = 200e18;
    vm.startBroadcast();  // ----------------------
    ERC20 token = ERC20(wsteth);
    token.transfer(recipient, amount);
    console.log("balance of recipient", token.balanceOf(recipient));
    vm.stopBroadcast();  // ----------------------------
  }
}
