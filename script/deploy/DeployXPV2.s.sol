// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {VaultManagerV3} from "../../src/core/VaultManagerV3.sol";
import {DNft} from "../../src/core/DNft.sol";
import {Dyad} from "../../src/core/Dyad.sol";
import {VaultLicenser} from "../../src/core/VaultLicenser.sol";
import {Parameters} from "../../src/params/Parameters.sol";
import {DyadXPv2} from "../../src/staking/DyadXPv2.sol";

contract DeployXPV2 is Script, Parameters {
    function run() external {
        vm.broadcast();
        DyadXPv2 xp = new DyadXPv2(
            Parameters.MAINNET_V2_VAULT_MANAGER, Parameters.MAINNET_V2_KEROSENE_V2_VAULT, Parameters.MAINNET_DNFT
        );

        vm.prank(Parameters.MAINNET_FEE_RECIPIENT);
        DyadXPv2(Parameters.MAINNET_V2_XP).upgradeToAndCall(address(xp), abi.encodeWithSignature("initialize()"));

        uint256 xpfornote = DyadXPv2(Parameters.MAINNET_V2_XP).balanceOfNote(467);
        console.log("XP for note 467", xpfornote);
    }
}
