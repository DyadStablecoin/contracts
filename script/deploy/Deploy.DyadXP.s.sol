// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {VaultManagerV4} from "../../src/core/VaultManagerV4.sol";
import {Parameters}     from "../../src/params/Parameters.sol";
import {DyadXP}       from "../../src/staking/DyadXP.sol";

contract DeployXP is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    DyadXP dyadXP = new DyadXP(MAINNET_V2_VAULT_MANAGER, MAINNET_V2_KEROSENE_V2_VAULT, MAINNET_DNFT);
    /// @dev we do the upgrade manually through the multi-sig UI
    VaultManagerV4 vm4 = new VaultManagerV4();

    vm.stopBroadcast();  // ----------------------------
  }
}
