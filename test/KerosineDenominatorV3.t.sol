// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {KerosineDenominatorV3} from "../src/staking/KerosineDenominatorV3.sol";
import {Kerosine} from "../src/staking/Kerosine.sol";
import {Dyad} from "../src/core/Dyad.sol";
import {OracleMock} from "./OracleMock.sol";
import {KerosineManager} from "../src/core/KerosineManager.sol";

contract TokenMock is ERC20Mock {
    constructor(string memory _name, string memory _symbol) ERC20Mock(_name, _symbol) {}

    function setBalance(address _target, uint256 _amount) external {
        _burn(_target, balanceOf[_target]);
        _mint(_target, _amount);
    }
}

contract VaultMock {
    OracleMock public oracle = new OracleMock(1e8);
    TokenMock public asset = new TokenMock("Asset", "AST");

    function assetPrice() public view returns (uint256) {
        (, uint256 answer,,,) = oracle.latestRoundData();
        return answer;
    }

    function setAssetBalance(uint256 _balance) external {
        asset.setBalance(address(this), _balance);
    }

    function getTvl() external view returns (uint256) {
        return
            asset.balanceOf(address(this)) * assetPrice() * 1e18 / (10 ** asset.decimals()) / (10 ** oracle.decimals());
    }
}

contract VaultManagerMock {
    address[] _vaults;

    function addVault(VaultMock _vault) external {
        _vaults.push(address(_vault));
    }

    function getVaults() external view returns (address[] memory) {
        return _vaults;
    }

    function getTvl() external view returns (uint256) {
        uint256 tvl;
        uint256 numberOfVaults = _vaults.length;
        for (uint256 i = 0; i < numberOfVaults; i++) {
            VaultMock vault = VaultMock(_vaults[i]);
            tvl += vault.getTvl();
        }

        return tvl;
    }
}

contract KerosineDenominatorV3Test is Test {
    address OWNER;
    address ALICE = makeAddr("ALICE");

    KerosineDenominatorV3 keroDenominator;
    TokenMock kerosine;
    TokenMock dyad;
    VaultManagerMock manager;

    function setUp() external {
        dyad = new TokenMock("DyadMock", "Dyad");
        dyad.mint(address(this), 100_000_000e18);

        kerosine = new TokenMock("KerosineMock", "Kerosine");
        kerosine.mint(address(this), 1_000_000_000e18);

        manager = new VaultManagerMock();
        VaultMock vault = new VaultMock();
        vault.setAssetBalance(1_000_000_000e18);
        manager.addVault(vault);

        keroDenominator = new KerosineDenominatorV3(
            Kerosine(address(kerosine)), Dyad(address(dyad)), KerosineManager(address(manager))
        );

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
        uint64 multiplier = 1.25e12;
        vm.prank(OWNER);
        keroDenominator.setTargetDyadMultiplier(multiplier, 0);

        // Set Dyad total supply
        dyad.setBalance(address(this), 10_000e18);

        uint256 dyadSupply = dyad.totalSupply();

        // Set kero total supply
        kerosine.setBalance(address(this), 100_000e18);

        uint80[25] memory systemTvls = [
            100000e18,
            95000e18,
            90000e18,
            85000e18,
            80000e18,
            75000e18,
            70000e18,
            65000e18,
            60000e18,
            55000e18,
            50000e18,
            45000e18,
            40000e18,
            35000e18,
            30000e18,
            25000e18,
            20000e18,
            15000e18,
            14000e18,
            13000e18,
            12750e18,
            12500e18,
            12250e18,
            12000e18,
            10000e18
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

        VaultMock vault = VaultMock(manager.getVaults()[0]);

        for (uint256 i; i < systemTvls.length; i++) {
            // Set TVL
            vault.setAssetBalance(systemTvls[i]);

            uint256 tvl = manager.getTvl();

            uint256 expectedPrice = expectedPrices[i];

            uint256 denominator = keroDenominator.denominator();

            uint256 actualPrice = ((tvl - dyadSupply) * 1e8) / denominator;

            assertEq(actualPrice, expectedPrice);
        }
    }
}
