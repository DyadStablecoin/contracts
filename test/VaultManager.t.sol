// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import {BaseTest} from "./BaseTest.sol";

contract VaultManagerTest is BaseTest {
  function test_add() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    vaultManager.add(id, address(vault));
    assertEq(vaultManager.vaults(id, 0), address(vault));
  }

  function test_remove() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    vaultManager.add(id, address(vault));
    vaultManager.remove(id, 0);
  }
}
