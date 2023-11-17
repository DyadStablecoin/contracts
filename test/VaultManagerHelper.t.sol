// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import {BaseTest} from "./BaseTest.sol";
import {ERC20Mock} from "./ERC20Mock.sol";

contract VaultManagerTestHelper is BaseTest {
  address constant RECEIVER = address(0xdead);

  address constant RANDOM_VAULT_1 = address(42);
  address constant RANDOM_VAULT_2 = address(314159);
  address constant RANDOM_VAULT_3 = address(69);

  function mintDNft() public returns (uint) {
    return dNft.mintNft{value: 1 ether}(address(this));
  }

  function addVault(uint id, address vault) public {
    vm.prank(vaultLicenser.owner());
    vaultLicenser.add(vault);
    vaultManager. add(id, vault);
  }

  function deposit(
    ERC20Mock token,
    uint      id,
    address   vault,
    uint      amount
  ) public {
    vaultManager.add(id, vault);
    token.mint(address(this), amount);
    token.approve(address(vaultManager), amount);
    vaultManager.deposit(id, address(vault), amount);
  }
}
