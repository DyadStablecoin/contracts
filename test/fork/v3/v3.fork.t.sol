// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {BaseTestV3}          from "./BaseV3.sol";
import {VaultManagerV3} from "../../../src/core/VaultManagerV3.sol";
import {Parameters} from "../../../src/params/Parameters.sol";
import {DeployVaultManagerV3} from "../../../script/deploy/DeployVaultManagerV3.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract V3ForkTest is BaseTestV3 {

  // function test_LiquidateXXX() public {
  //   contracts.vaultManager.liquidate(1, 2, 30);

  //   console.log("test");
  // }

  modifier mintDyad(uint id, uint amount) {
    vm.prank(contracts.dNft.ownerOf(id));
    contracts.vaultManager.mintDyad(id, amount, address(this));
    _;
  }

  modifier liquidate(uint id, uint to, address liquidator) {
    deal(address(contracts.dyad), liquidator, _ethToUSD(getMintedDyad(id)));
    vm.prank(liquidator);
    contracts.vaultManager.liquidate(id, to, getMintedDyad(id));
    _;
  }

  function test_LiquidateXXX() 
    public 
      // alice 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit (alice0, contracts.ethVault, 100 ether)
      mintDyad(alice0, _ethToUSD(1 ether))
      changeAsset(alice0, contracts.ethVault, 1.2 ether)

      // bob
      mintBob0 
      liquidate(alice0, bob0, bob)
  {
    uint ethAfter_Liquidator  = contracts.ethVault.id2asset(bob0);
    uint ethAfter_Liquidatee  = contracts.ethVault.id2asset(alice0);
    uint dyadAfter_Liquidatee = contracts.dyad.mintedDyad(alice0);

    assertTrue(ethAfter_Liquidator > 0);
    assertTrue(ethAfter_Liquidatee == 0);

    assertEq(getMintedDyad(alice0), 0);
    assertEq(getCR(alice0), type(uint256).max);
    assertEq(dyadAfter_Liquidatee, 0);
  }

}
