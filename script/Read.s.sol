// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {DNft} from "../src/core/DNft.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {Dyad} from "../src/core/Dyad.sol";

contract Read is Script {
  function run() public {
    uint count;
    IVault vault = IVault(0x48600800502a8dc7A2C42f39B21f0326Ad67dc4f);
    DNft dnft = DNft(0xDc400bBe0B8B79C07A962EA99a642F5819e3b712);
    for (uint256 i = 0; i < 800; i++) {
      uint assets = vault.id2asset(i);
      if (assets != 0) {
        count++;
        console.log(dnft.ownerOf(i));
        console.log(assets);
      }
    }
    console.log("count: ", count);
  }
}
