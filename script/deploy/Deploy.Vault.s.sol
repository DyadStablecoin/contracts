// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {Parameters}   from "../../src/params/Parameters.sol";
import {Vault} from "../../src/core/Vault.sol";
import {VaultManager}  from "../../src/core/VaultManager.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployPayments is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    Vault vault = new Vault(
      VaultManager (MAINNET_VAULT_MANAGER), 
      ERC20        (MAINNET_WETH), 
      IAggregatorV3(MAINNET_CHAINLINK_STETH)
    );

    vm.stopBroadcast();  // ----------------------------
  }
}

