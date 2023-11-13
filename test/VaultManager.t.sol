// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import {VaultManagerTestHelper} from "./VaultManagerHelper.t.sol";
import {IVaultManager} from "../src/interfaces/IVaultManager.sol";

contract VaultManagerTest is VaultManagerTestHelper {

  ///////////////////////////
  // add
  function test_add() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    vaultManager.add(id, address(vault));
    assertEq(vaultManager.vaults(id, 0), address(vault));
  }

  function test_addTwoVaults() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    addVault(id, RANDOM_VAULT_1);
    addVault(id, RANDOM_VAULT_2);
    assertEq(vaultManager.isDNftVault(id, RANDOM_VAULT_1), true);
    assertEq(vaultManager.isDNftVault(id, RANDOM_VAULT_2), true);
    assertEq(vaultManager.vaults(id, 0), RANDOM_VAULT_1);
    assertEq(vaultManager.vaults(id, 1), RANDOM_VAULT_2);
    vm.expectRevert();
    vaultManager.vaults(id, 2); // out of bounds
  }

  function testCannot_add_exceptForDNftOwner() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    vm.prank(address(1));
    vm.expectRevert(IVaultManager.NotOwner.selector);
    vaultManager.add(id, address(vault));
  }

  function testFail_add_moreThanMaxNumberOfVaults() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));

    for (uint i = 0; i < vaultManager.MAX_VAULTS(); i++) {
      addVault(id, address(uint160(i)));
    }
    // this puts it exactly one over the limit and should fail
    addVault(id, RANDOM_VAULT_1); 
  }

  function testCannot_add_unlicensedVault() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    vm.expectRevert(IVaultManager.VaultNotLicensed.selector);
    vaultManager.add(id, RANDOM_VAULT_1);
  }

  function testFail_cannotAddSameVaultTwice() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    addVault(id, RANDOM_VAULT_1);
    addVault(id, RANDOM_VAULT_1);
  }

  ///////////////////////////
  // remove
  function test_remove() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    vaultManager.add(id, address(vault));
    vaultManager.remove(id, address(vault));
  }

  function testCannot_remove_exceptForDNftOwner() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    vaultManager.add(id, address(vault));
    vm.prank(address(1));
    vm.expectRevert(IVaultManager.NotOwner.selector);
    vaultManager.remove(id, address(vault));
  }

  ///////////////////////////
  // deposit
  function test_deposit() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    vaultManager.add(id, address(vault));
    uint AMOUNT = 1e18;
    weth.mint(address(this), AMOUNT);
    weth.approve(address(vaultManager), AMOUNT);
    vaultManager.deposit(id, address(vault), AMOUNT);
  }
}
