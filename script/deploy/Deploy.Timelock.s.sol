// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/governance/TimelockController.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Parameters} from "../../src/params/Parameters.sol";

contract DeployTimelock is Script, Parameters {
    function run() public {
        address[] memory proposers = new address[](1);
        proposers[0] = MAINNET_OWNER;

        address[] memory executors = new address[](1);
        executors[0] = MAINNET_OWNER;

        vm.startBroadcast(); // ----------------------

        TimelockController timelock = new TimelockController(
          7 days,
          proposers,
          executors,
          MAINNET_OWNER
        );

        vm.stopBroadcast(); // ----------------------------
    }
}
