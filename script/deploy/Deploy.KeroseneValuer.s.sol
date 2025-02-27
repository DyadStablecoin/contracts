// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Parameters} from "../../src/params/Parameters.sol";
import {KeroseneValuer} from "../../src/staking/KeroseneValuer.sol";
import {Dyad} from "../../src/core/Dyad.sol";
import {Kerosine} from "../../src/staking/Kerosine.sol";
import {KerosineManager} from "../../src/core/KerosineManager.sol";

contract DeployKerosenseValuer is Script, Parameters {
    function run() external {
        vm.startBroadcast();

        KeroseneValuer keroseneValuer = new KeroseneValuer(
            Kerosine(MAINNET_KEROSENE), KerosineManager(MAINNET_V2_KEROSENE_MANAGER), Dyad(MAINNET_V2_DYAD)
        );

        console.log("KeroseneValuer deployed at: ", address(keroseneValuer));

        vm.stopBroadcast();
    }
}
