// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {Kerosine}   from "../../src/staking/Kerosine.sol";
import {Parameters} from "../../src/params/Parameters.sol";

contract DeployKerosine is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    Kerosine kerosine = new Kerosine();
    kerosine.transfer(MAINNET_OWNER, kerosine.totalSupply());

    vm.stopBroadcast();  // ----------------------------
  }
}
