// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Parameters} from "../../src/params/Parameters.sol";
import {Modifiers}  from "../Modifiers.sol";

contract BaseTestV2 is Modifiers, Parameters {

  // --- RECEIVER ---
  receive() external payable {}

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure returns (bytes4) {
    return 0x150b7a02;
  }

}
