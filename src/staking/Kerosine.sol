// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract Kerosine is ERC20("Kerosene", "KEROSENE", 18) {

  constructor() {
      _mint(msg.sender, 1_000_000_000 * 10**18); // 1 billion
  }

}
