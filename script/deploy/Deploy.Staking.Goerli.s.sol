// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import {StakingDeployBase} from "./DeployBase.Staking.s.sol";
import {Parameters} from "../../src/params/Parameters.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployStakingGoerli is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    new StakingDeployBase().deploy(
      GOERLI_OWNER,
      1_000_000 * 10**18,
      5 days,
      ERC20(GOERLI_WETH_DYAD_UNI)
    );

    vm.stopBroadcast();  // ----------------------------
  }
}

