// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import {BaseTest} from "./BaseTest.sol";
import {Parameters} from "../src/Parameters.sol";
import {IDNft} from "../src/interfaces/IDNft.sol";
import {SharesMath} from "../src/libraries/SharesMath.sol";

contract DNftsTest is BaseTest {
  function test_Constructor() public {
    assertEq(dNft.owner(), MAINNET_OWNER);
    assertEq(dyad.owner(), address(dNft));
    assertTrue(address(dNft.oracle()) != address(0));
  }

  // -------------------- mintNft --------------------
  function test_mintNft() public {
    dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
  }
  function testCannot_mintNft_publicMintsExceeded() public {
    for(uint i = 0; i < dNft.PUBLIC_MINTS(); i++) {
      dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    }
    uint ethSacrifice = dNft.ETH_SACRIFICE();
    vm.expectRevert();
    dNft.mintNft{value: ethSacrifice}(address(this));
  }

  // -------------------- mintInsiderNft --------------------
  function test_mintInsiderNft() public {
    vm.prank(MAINNET_OWNER);
    dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
  }
  function testCannot_mintInsiderNft_NotOwner() public {
    vm.expectRevert();
    dNft.mintInsiderNft(address(this));
  }
  function testCannot_mintInsiderNft_insiderMintsExceeded() public {
    for(uint i = 0; i < dNft.INSIDER_MINTS(); i++) {
      dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    }
    vm.expectRevert();
    dNft.mintInsiderNft(address(this));
  }

  // -------------------- deposit --------------------
  function test_deposit() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    assertEq(dNft.id2eth(id), 0 ether);
    dNft.deposit{value: 10 ether}(id);
    assertEq(dNft.id2eth(id), 10 ether);
  }

  // -------------------- withdraw --------------------
  function test_withdraw() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    dNft.withdraw(id, address(this), 1 ether);
  }
  function testCannot_withdraw_notNftOwner() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    vm.prank(address(1));
    vm.expectRevert();
    dNft.withdraw(id, address(this), 1 ether);
  }
  function testCannot_withdraw_moreThanCollateral() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    vm.expectRevert();
    dNft.withdraw(id, address(this), 2 ether);
  }
  function testCannot_withdraw_moreThanCollateralRatio() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    dNft.mintDyad(id, address(this), 300 ether);
    vm.expectRevert();
    dNft.withdraw(id, address(this), 0.3 ether);
  }

  // -------------------- mintDyad --------------------
  function test_mintDyad() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    dNft.mintDyad(id, address(this), 300 ether);
  }
  function testCannot_mintDyad_notNftOwner() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    vm.prank(address(1));
    vm.expectRevert();
    dNft.mintDyad(id, address(this), 300 ether);
  }
  function testCannot_mintDyad_moreThanCollateralRatio() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    vm.expectRevert();
    dNft.mintDyad(id, address(this), 400 ether);
  }

  // -------------------- liquidate --------------------
  function test_liquidate() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    dNft.mintDyad(id, address(this), 300 ether);
    oracleMock.setPrice(100e8);
    uint ethVaultBefore = dNft.id2eth(id);
    dNft.liquidate{value: 10 ether}(id, address(1));
    assertTrue(ethVaultBefore < dNft.id2eth(id));
  }
  function testCannot_liquidate_CrTooHigh() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    vm.expectRevert();
    dNft.liquidate{value: 10 ether}(id, address(1));
  }
  function testCannot_liquidate_CrTooLow() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    dNft.mintDyad(id, address(this), 300 ether);
    oracleMock.setPrice(100e8);
    vm.expectRevert();
    dNft.liquidate{value: 1 ether}(id, address(1));
  }

  // -------------------- redeem --------------------
  function test_redeem() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    dNft.mintDyad(id, address(this), 300 ether);
    assertEq(dyad.balanceOf(address(this)), 300 ether);
    uint ethBefore = address(this).balance;
    uint ethVaultBefore = dNft.id2eth(id);
    assertEq(dyad.balanceOf(address(this)), 300 ether);
    assertEq(dNft.id2dyad(id), 300 ether);
    dNft.redeem(id, address(this), 300 ether);
    assertEq(dyad.balanceOf(address(this)), 0 ether);
    assertTrue(ethBefore < address(this).balance);
    assertTrue(ethVaultBefore > dNft.id2eth(id));
    assertEq(dyad.balanceOf(address(this)), 0);
    assertEq(dNft.id2dyad(id), 0);
  }
  function testCannot_redeem_notNftOwner() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    dNft.mintDyad(id, address(this), 300 ether);
    vm.prank(address(1));
    vm.expectRevert();
    dNft.redeem(id, address(this), 300 ether);
  }
  function testCannot_redeem_moreThanWithdrawn() public {
    uint id = dNft.mintNft{value: dNft.ETH_SACRIFICE()}(address(this));
    dNft.deposit{value: 1 ether}(id);
    dNft.mintDyad(id, address(this), 300 ether);
    vm.expectRevert();
    dNft.redeem(id, address(this), 400 ether);
  }
}
