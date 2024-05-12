// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {Parameters} from "../../src/params/Parameters.sol";

/**
 * This script allows us to transfer any arbitrary token to a recipient.
 * NOTE:
 * - Make sure `msg.sender` actually has the tokens. Check Etherscan for this.
 * - Make sure you are impersonating `msg.sender` with the tokens in your anvil
 *   instance.
 */
contract Transfer is Script, Parameters {
  address TOKEN     = MAINNET_KEROSENE;
  address RECIPIENT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  uint    AMOUNT    = 1e18;

  function run() public {

    vm.startBroadcast();  // ----------------------
    console.log(msg.sender);

    ERC20 token = ERC20(TOKEN);
    token.transfer(RECIPIENT, AMOUNT);

    vm.stopBroadcast();  // ----------------------------

    console.log("balance of recipient", token.balanceOf(RECIPIENT));
  }
}
