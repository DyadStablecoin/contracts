// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract Modifiers is Test {
  modifier skipBlock    (uint blocks)     { vm.roll(block.number + blocks); _; }
  modifier nextCallFails(bytes4 selector) { vm.expectRevert(selector);      _; }
  modifier startPrank   (address owner)   { vm.startPrank(owner);           _; }
  modifier stopPrank    ()                { vm.stopPrank();                 _; }
}
