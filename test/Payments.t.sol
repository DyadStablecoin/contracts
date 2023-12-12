// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";

import {BaseTest} from "./BaseTest.sol";

contract PaymentsTest is BaseTest {

  function test_deposit() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));
    uint amount = 120e18;

    vaultManager.add(id, address(wethVault));
    weth.mint(address(this), amount);

    weth.approve(address(payments), amount);
    payments.depositWithFee(id, address(wethVault), amount);
  }

  function test_depositETHWithFee() public {
    uint id = dNft.mintNft{value: 1 ether}(address(this));

    vaultManager.add(id, address(wethVault));
    payments.depositETHWithFee{value: 1 ether}(id, address(wethVault));
  }
}
