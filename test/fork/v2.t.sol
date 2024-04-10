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

  function testDenominator() public {
    uint denominator = contracts.kerosineDenominator.denominator();
    console.log(denominator);
  }
}
