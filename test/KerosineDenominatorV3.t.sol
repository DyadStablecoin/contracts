// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {KerosineDenominatorV3} from "../src/staking/KerosineDenominatorV3.sol";
import {Kerosine} from "../src/staking/Kerosine.sol";
import {Dyad} from "../src/core/Dyad.sol";
import {OracleMock} from "./OracleMock.sol";
import {KerosineManager} from "../src/core/KerosineManager.sol";

contract FakeAsset {
    mapping(address account => uint256 balance) _balances;

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function balanceOf(address _account) external view returns (uint256) {
        return _balances[_account];
    }

    function setBalance(address _target, uint256 _balance) external {
        _balances[_target] = _balance;
    }
}

contract FakeVault {
    OracleMock public oracle = new OracleMock(1e8);
    FakeAsset public asset = new FakeAsset();

    constructor() {
        asset.setBalance(address(this), 1_000_000_000e18);
    }

    function assetPrice() external view returns (uint256) {
        (, uint256 answer,,,) = oracle.latestRoundData();
        return answer;
    }
}

contract FakeDyad {
    uint256 _totalSupply;

    function setTotalSupply(uint256 _newTotalSupply) external {
        _totalSupply = _newTotalSupply;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
}

contract FakeVaultManager {
    address[] _vaults;

    function addVault(FakeVault _vault) external {
        _vaults.push(address(_vault));
    }

    function getVaults() external view returns (address[] memory) {
        return _vaults;
    }

    function getTvl() external view returns (uint256) {
        uint256 tvl;
        uint256 numberOfVaults = _vaults.length;
        for (uint256 i = 0; i < numberOfVaults; i++) {
            FakeVault vault = FakeVault(_vaults[i]);
            FakeAsset asset = vault.asset();
            tvl += asset.balanceOf(address(vault)) * vault.assetPrice() * 1e18 / (10 ** asset.decimals())
                / (10 ** vault.oracle().decimals());
        }

        return tvl;
    }
}

contract KerosineDenominatorV3Test is Test {
    address OWNER;
    address ALICE = makeAddr("ALICE");

    KerosineDenominatorV3 keroDenominator;
    Kerosine kerosine;
    FakeDyad dyad;
    FakeVaultManager manager;

    function setUp() external {
        dyad = new FakeDyad();
        dyad.setTotalSupply(100_000_000e18);
        manager = new FakeVaultManager();
        manager.addVault(new FakeVault());
        kerosine = new Kerosine();
        keroDenominator = new KerosineDenominatorV3(kerosine, Dyad(address(dyad)), KerosineManager(address(manager)));
        OWNER = keroDenominator.owner();
    }

    function test_get_multiplier() external view {
        uint64 multiplier = keroDenominator.currentDyadMultiplier();

        // Default value
        assertEq(multiplier, 1e12);
    }

    function test_set_multiplier() external {
        uint64 newMultiplier = 1.25e12;
        uint32 duration = 2 hours;

        vm.prank(OWNER);
        keroDenominator.setTargetDyadMultiplier(newMultiplier, duration);

        assertEq(keroDenominator.dyadMultiplierSnapshot(), 1e12);
        assertEq(keroDenominator.dyadMultiplierSnapshotTimestamp(), vm.getBlockTimestamp());
        assertEq(keroDenominator.targetDyadMultiplier(), newMultiplier);
        assertEq(keroDenominator.targetDyadMultiplierTimestamp(), vm.getBlockTimestamp() + duration);
        // Current multiplier stays the same right after update
        assertEq(keroDenominator.currentDyadMultiplier(), 1e12);
    }

    function test_multiplier_increase() external {
        uint64 newMultiplier = 2e12;
        uint32 duration = 10 seconds;

        uint64 increasePerSecond = (newMultiplier - keroDenominator.currentDyadMultiplier()) / duration;

        vm.prank(OWNER);
        keroDenominator.setTargetDyadMultiplier(newMultiplier, duration);

        uint64 multiplierSnapshot = keroDenominator.dyadMultiplierSnapshot();

        // after 1 second
        vm.warp(vm.getBlockTimestamp() + 1 seconds);
        assertEq(keroDenominator.currentDyadMultiplier(), multiplierSnapshot + increasePerSecond);

        // after 8 seconds
        vm.warp(vm.getBlockTimestamp() + 7 seconds);
        assertEq(keroDenominator.currentDyadMultiplier(), multiplierSnapshot + 8 * increasePerSecond);

        // after 10 seconds
        vm.warp(vm.getBlockTimestamp() + 2 seconds);
        assertEq(keroDenominator.currentDyadMultiplier(), newMultiplier);

        // after some time
        vm.warp(vm.getBlockTimestamp() + 1 hours);
        assertEq(keroDenominator.currentDyadMultiplier(), newMultiplier);
    }

    function test_multiplier_decrease() external {
        vm.prank(OWNER);
        keroDenominator.setTargetDyadMultiplier(2e12, 0);

        uint64 newMultiplier = 1.2e12;
        uint32 duration = 10 seconds;

        uint64 decreasePerSecond = (keroDenominator.currentDyadMultiplier() - newMultiplier) / duration;

        vm.prank(OWNER);
        keroDenominator.setTargetDyadMultiplier(newMultiplier, duration);

        uint64 multiplierSnapshot = keroDenominator.dyadMultiplierSnapshot();

        // after 1 second
        vm.warp(vm.getBlockTimestamp() + 1 seconds);
        assertEq(keroDenominator.currentDyadMultiplier(), multiplierSnapshot - decreasePerSecond);

        // after 8 seconds
        vm.warp(vm.getBlockTimestamp() + 7 seconds);
        assertEq(keroDenominator.currentDyadMultiplier(), multiplierSnapshot - 8 * decreasePerSecond);

        // after 10 seconds
        vm.warp(vm.getBlockTimestamp() + 2 seconds);
        assertEq(keroDenominator.currentDyadMultiplier(), newMultiplier);

        // after some time
        vm.warp(vm.getBlockTimestamp() + 1 hours);
        assertEq(keroDenominator.currentDyadMultiplier(), newMultiplier);
    }

    function test_kerosine_deterministic_value() external {
        uint64 multiplier = 2e12;
        vm.prank(OWNER);
        keroDenominator.setTargetDyadMultiplier(multiplier, 0);

        // Default is $1 billion
        uint256 tvl = manager.getTvl();
        // Default is $100 millions
        uint256 dyadSupply = dyad.totalSupply();

        // expected deterministic price
        // (tvl - x * dyad supply) / kero supply
        uint256 expectedPrice = ((tvl - (multiplier * dyadSupply) / 1e12) * 1e8) / kerosine.totalSupply();

        uint256 denominator = keroDenominator.denominator();

        uint256 actualPrice = ((tvl - dyadSupply) * 1e8) / denominator;

        assertEq(actualPrice, expectedPrice);
    }
}
