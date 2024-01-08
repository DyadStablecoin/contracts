// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {Parameters}   from "../../src/params/Parameters.sol";
import {VaultWstEth} from "../../src/core/Vault.wsteth.sol";
import {VaultManager}  from "../../src/core/VaultManager.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";
import {IWstETH} from "../../src/interfaces/IWstETH.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployVault is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    new VaultWstEth(
      VaultManager (GOERLI_VAULT_MANAGER), 
      ERC20        (GOERLI_WETH), 
      IAggregatorV3(GOERLI_CHAINLINK_STETH),
      IWstETH      (GOERLI_WSTETH)
    );

    vm.stopBroadcast();  // ----------------------------
  }
}

