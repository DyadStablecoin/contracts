// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {DyadLPStakingFactory} from "../../src/staking/DyadLPStakingFactory.sol";

contract DeployStaking is Script, Parameters {
    function run() public {
        vm.startBroadcast(); // ----------------------

        DyadLPStakingFactory factory = new DyadLPStakingFactory(
            MAINNET_KEROSENE, 
            MAINNET_DNFT,
            MAINNET_V2_KEROSENE_V2_VAULT,
            MAINNET_V2_VAULT_MANAGER
        );

        factory.createPoolStaking(address(0));

        factory.grantRoles(MAINNET_OWNER, type(uint256).max);
        factory.transferOwnership(MAINNET_OWNER);

        vm.stopBroadcast(); // ----------------------------
    }
}

