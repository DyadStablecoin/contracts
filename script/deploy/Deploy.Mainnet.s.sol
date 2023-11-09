// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import {DeployBase} from "./DeployBase.s.sol";
import {Parameters} from "../../src/Parameters.sol";

contract DeployMainnet is Script, Parameters {
  function run() public {
      new DeployBase().deploy(
        MAINNET_ORACLE,
        MAINNET_OWNER
      );
  }
}

