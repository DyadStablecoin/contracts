// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";

import {BaseTestV2}          from "../fork/BaseV2.sol";
import {Licenser}            from "../../src/core/Licenser.sol";
import {IVaultManager}       from "../../src/interfaces/IVaultManager.sol";
import {IVault}              from "../../src/interfaces/IVault.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract V2TestFuzz is BaseTestV2 {
  function testFuzz_Deposit(uint amount) 
    public 
      mintAlice0
      addVault(alice0, contracts.ethVault)
      deposit (alice0, contracts.ethVault, amount)
  {}
}
