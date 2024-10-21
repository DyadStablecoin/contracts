// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {DyadLPStaking} from "../../src/staking/DyadLPStaking.sol";

contract DeployStaking is Script, Parameters {
    function run() public {
        vm.startBroadcast(); // ----------------------

        new DyadLPStaking(
            address(0),
            MAINNET_DNFT,
            MAINNET_OWNER
        );

        vm.stopBroadcast(); // ----------------------------
    }
}

