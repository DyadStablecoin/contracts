// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {Parameters} from "../../src/params/Parameters.sol";
import {VaultWeETH} from "../../src/core/Vault.weETH.sol";
import {VaultManager} from "../../src/core/VaultManager.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";
import {IWstETH} from "../../src/interfaces/IWstETH.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployVault is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    new VaultWeETH(
      VaultManager (MAINNET_V2_VAULT_MANAGER), 
      ERC20        (0xcd5fe23c85820f7b72d0926fc9b05b43e359b7ee), 
      IAggregatorV3(0x5c9C449BbC9a6075A2c061dF312a35fd1E05fF22)
    );

    vm.stopBroadcast();  // ----------------------------
  }
}


