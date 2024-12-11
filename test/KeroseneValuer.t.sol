// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {KeroseneValuer} from "../src/staking/KeroseneValuer.sol";
import {Kerosine} from "../src/staking/Kerosine.sol";

contract KeroseneValuerTest is Test {
    address OWNER;
    address ALICE = makeAddr("ALICE");

    KeroseneValuer valuer;
    Kerosine kerosene;

    function setUp() external {
        kerosene = new Kerosine();

        valuer = new KeroseneValuer(kerosene);

        OWNER = valuer.owner();
    }

    function test_get_multiplier() external view {
        uint64 multiplier = valuer.currentDyadMultiplier();

        // Default value
        assertEq(multiplier, 1e12);
    }

    function test_set_multiplier() external {
        uint64 newMultiplier = 1.25e12;
        uint32 duration = 2 hours;

        vm.prank(OWNER);
        valuer.setTargetDyadMultiplier(newMultiplier, duration);

        assertEq(valuer.dyadMultiplierSnapshot(), 1e12);
        assertEq(valuer.dyadMultiplierSnapshotTimestamp(), vm.getBlockTimestamp());
        assertEq(valuer.targetDyadMultiplier(), newMultiplier);
        assertEq(valuer.targetDyadMultiplierTimestamp(), vm.getBlockTimestamp() + duration);
        // Current multiplier stays the same right after update
        assertEq(valuer.currentDyadMultiplier(), 1e12);
    }

    function test_multiplier_increase() external {
        uint64 newMultiplier = 2e12;
        uint32 duration = 10 seconds;

        uint64 increasePerSecond = (newMultiplier - valuer.currentDyadMultiplier()) / duration;

        vm.prank(OWNER);
        valuer.setTargetDyadMultiplier(newMultiplier, duration);

        uint64 multiplierSnapshot = valuer.dyadMultiplierSnapshot();

        // after 1 second
        vm.warp(vm.getBlockTimestamp() + 1 seconds);
        assertEq(valuer.currentDyadMultiplier(), multiplierSnapshot + increasePerSecond);

        // after 8 seconds
        vm.warp(vm.getBlockTimestamp() + 7 seconds);
        assertEq(valuer.currentDyadMultiplier(), multiplierSnapshot + 8 * increasePerSecond);

        // after 10 seconds
        vm.warp(vm.getBlockTimestamp() + 2 seconds);
        assertEq(valuer.currentDyadMultiplier(), newMultiplier);

        // after some time
        vm.warp(vm.getBlockTimestamp() + 1 hours);
        assertEq(valuer.currentDyadMultiplier(), newMultiplier);
    }

    function test_multiplier_decrease() external {
        vm.prank(OWNER);
        valuer.setTargetDyadMultiplier(2e12, 0);

        uint64 newMultiplier = 1.2e12;
        uint32 duration = 10 seconds;

        uint64 decreasePerSecond = (valuer.currentDyadMultiplier() - newMultiplier) / duration;

        vm.prank(OWNER);
        valuer.setTargetDyadMultiplier(newMultiplier, duration);

        uint64 multiplierSnapshot = valuer.dyadMultiplierSnapshot();

        // after 1 second
        vm.warp(vm.getBlockTimestamp() + 1 seconds);
        assertEq(valuer.currentDyadMultiplier(), multiplierSnapshot - decreasePerSecond);

        // after 8 seconds
        vm.warp(vm.getBlockTimestamp() + 7 seconds);
        assertEq(valuer.currentDyadMultiplier(), multiplierSnapshot - 8 * decreasePerSecond);

        // after 10 seconds
        vm.warp(vm.getBlockTimestamp() + 2 seconds);
        assertEq(valuer.currentDyadMultiplier(), newMultiplier);

        // after some time
        vm.warp(vm.getBlockTimestamp() + 1 hours);
        assertEq(valuer.currentDyadMultiplier(), newMultiplier);
    }

    function test_kerosine_deterministic_value() external {
        uint64 multiplier = 1.25e12;
        vm.prank(OWNER);
        valuer.setTargetDyadMultiplier(multiplier, 0);
        uint256 dyadSupply = 100_000_000e18;

        uint96[25] memory systemTvls = [
            1_000_000_000e18,
            950_000_000e18,
            900_000_000e18,
            850_000_000e18,
            800_000_000e18,
            750_000_000e18,
            700_000_000e18,
            650_000_000e18,
            600_000_000e18,
            550_000_000e18,
            500_000_000e18,
            450_000_000e18,
            400_000_000e18,
            350_000_000e18,
            300_000_000e18,
            250_000_000e18,
            200_000_000e18,
            150_000_000e18,
            140_000_000e18,
            130_000_000e18,
            127_500_000e18,
            125_000_000e18,
            122_500_000e18,
            120_000_000e18,
            100_000_000e18
        ];

        uint32[25] memory expectedPrices = [
            0.875e8,
            0.825e8,
            0.775e8,
            0.725e8,
            0.675e8,
            0.625e8,
            0.575e8,
            0.525e8,
            0.475e8,
            0.425e8,
            0.375e8,
            0.325e8,
            0.275e8,
            0.225e8,
            0.175e8,
            0.125e8,
            0.075e8,
            0.025e8,
            0.015e8,
            0.005e8,
            0.0025e8,
            0.0,
            0.0,
            0.0,
            0.0
        ];

        for (uint256 i; i < systemTvls.length; i++) {
            uint256 expectedPrice = expectedPrices[i];

            uint256 deterministicValue = valuer.deterministicValue(systemTvls[i], dyadSupply);

            assertEq(deterministicValue, expectedPrice);
        }
    }
}
