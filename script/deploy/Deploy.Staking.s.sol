// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {DyadLPStakingFactory} from "../../src/staking/DyadLPStakingFactory.sol";
import {DyadLPStaking} from "../../src/staking/DyadLPStaking.sol";
import {Parameters} from "../../src/params/Parameters.sol";

contract DeployStaking is Script, Parameters {
    function run() public {
        vm.startBroadcast(); // ----------------------

        DyadLPStakingFactory factory = new DyadLPStakingFactory(
            MAINNET_KEROSENE, MAINNET_DNFT, MAINNET_V2_KEROSENE_V2_VAULT, MAINNET_V2_VAULT_MANAGER
        );

        DyadLPStaking staking = DyadLPStaking(factory.createPoolStaking(MAINNET_CURVE_M0_DYAD));

        staking.transferOwnership(MAINNET_OWNER);
        factory.transferOwnership(MAINNET_OWNER);

        vm.stopBroadcast(); // ----------------------------
    }
}
