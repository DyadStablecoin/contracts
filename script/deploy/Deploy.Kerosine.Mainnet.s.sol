// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import {KerosineDeployBase} from "./DeployBase.Kerosine.sol";
import {Parameters}         from "../../src/params/Parameters.sol";
import {VaultManager}       from "../../src/core/VaultManager.sol";
import {Dyad}               from "../../src/core/Dyad.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployKerosine is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    new KerosineDeployBase().deploy(
      MAINNET_OWNER, 
      ERC20(MAINNET_WETH_DYAD_UNI),
      VaultManager(MAINNET_VAULT_MANAGER), 
      Dyad(MAINNET_DYAD)
    );

    vm.stopBroadcast();  // ----------------------------
  }
}
