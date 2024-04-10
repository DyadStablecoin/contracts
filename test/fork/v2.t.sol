// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import {DeployV2, Contracts} from "../../script/deploy/Deploy.V2.s.sol";
import {Licenser} from "../../src/core/Licenser.sol";
import {Parameters} from "../../src/params/Parameters.sol";

contract V2Test is Test, Parameters {

  Contracts contracts;

  function setUp() public {
    contracts = new DeployV2().run();
  }

  function testLicenseVaultManager() public {
    Licenser licenser = Licenser(MAINNET_VAULT_MANAGER_LICENSER);
    vm.prank(MAINNET_OWNER);
    licenser.add(address(contracts.vaultManager));
  }

  function testLicenseVaults() public {
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.ethVault));
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.wstEth));
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.unboundedKerosineVault));
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.boundedKerosineVault));
  }

  function testKeroseneVaults() public {
    address[] memory vaults = contracts.kerosineManager.getVaults();
    assertEq(vaults.length, 2);
    assertEq(vaults[0], address(contracts.ethVault));
    assertEq(vaults[1], address(contracts.wstEth));
  }

  function testOwnership() public {
    assertEq(contracts.kerosineManager.owner(),        MAINNET_OWNER);
    assertEq(contracts.vaultLicenser.owner(),          MAINNET_OWNER);
    assertEq(contracts.kerosineManager.owner(),        MAINNET_OWNER);
    assertEq(contracts.unboundedKerosineVault.owner(), MAINNET_OWNER);
    assertEq(contracts.boundedKerosineVault.owner(),   MAINNET_OWNER);
  }

  function testDenominator() public {
    uint denominator = contracts.kerosineDenominator.denominator();
    assertTrue(denominator < contracts.kerosene.balanceOf(MAINNET_OWNER));
  }
}
