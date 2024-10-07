// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import {VaultManagerV3} from "../../../src/core/VaultManagerV3.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Parameters} from "../../../src/params/Parameters.sol";

contract DeployV3Test is Test, Parameters {
    function test_Deployment() public {
        VaultManagerV3 vm3 = new VaultManagerV3();

        UUPSUpgradeable proxy = UUPSUpgradeable(MAINNET_V2_VAULT_MANAGER);

        vm.startPrank(MAINNET_OWNER);
        console.logBytes(abi.encodeCall(VaultManagerV3.initialize, ()));
        proxy.upgradeToAndCall(address(vm3), abi.encodeCall(VaultManagerV3.initialize, ()));
        // proxy.upgradeToAndCall(address(vm3), "0x8129fc1c");
        vm.stopPrank();

        vm3 = VaultManagerV3(address(proxy));

        assertEq(address(proxy), MAINNET_V2_VAULT_MANAGER);
        assertEq(vm3.MAX_VAULTS(), 6);

        console.log(vm3.owner());
        assertEq(vm3.owner(), MAINNET_OWNER);
    }
}
