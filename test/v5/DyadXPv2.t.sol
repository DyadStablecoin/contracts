// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTestV5} from "./BaseTestV5.sol";

contract DyadXPv2Test is BaseTestV5 {

    function setUp() public virtual override {
        super.setUp();
        
        vm.startPrank(USER_1);
        vaultManager.add(0, address(wethVault));
        vaultManager.add(0, address(keroseneVault));
        vm.stopPrank();
    }

    function test_XPAccrualNoDyad() public {
        kerosene.transfer(USER_1, 100_000 ether);

        vm.startPrank(USER_1);
        kerosene.approve(address(vaultManager), type(uint256).max);
        vaultManager.deposit(0, address(keroseneVault), 100_000 ether);
        
        assertEq(dyadXP.balanceOfNote(0), 0);
        assertEq(dyadXP.accrualRate(0), 100_000 ether);
    }

    function test_XPAccrualWithDyad() public {
        kerosene.transfer(USER_1, 100_000 ether);
        vm.deal(USER_1, 100 ether);

        _mockOracleResponse(address(wethVault.oracle()), 250000000000, 8);
    
        vm.startPrank(USER_1);
        weth.deposit{value: 100 ether}();
        weth.approve(address(vaultManager), type(uint256).max);
        vaultManager.deposit(0, address(wethVault), 100 ether);
        kerosene.approve(address(vaultManager), type(uint256).max);
        vaultManager.deposit(0, address(keroseneVault), 100_000 ether);
        vaultManager.mintDyad(0, 100_000 ether, USER_1);
        
        assertEq(dyadXP.balanceOfNote(0), 0);
        assertEq(dyadXP.accrualRate(0), 150_000 ether);
    }

    function test_XPHalving() public {
        uint256 halvingStart = block.timestamp + 7 days;
        dyadXP.setHalvingConfiguration(uint40(halvingStart), 7 days);

        kerosene.transfer(USER_1, 200_000 ether);

        vm.startPrank(USER_1);
        kerosene.approve(address(vaultManager), type(uint256).max);
        vaultManager.deposit(0, address(keroseneVault), 100_000 ether);
        vm.roll(block.number + 1);
        vm.stopPrank();

        skip(7 days);
        vm.warp(halvingStart);
        assertEq(dyadXP.balanceOfNote(0), 60_480_000_000 ether);

        skip(7 days - 1);
        assertEq(dyadXP.balanceOfNote(0), 120_959_900_000 ether);

        skip(1);
        assertEq(dyadXP.balanceOfNote(0), 60_480_000_000 ether);

        _mockOracleResponse(address(wethVault.oracle()), 200000000000, 8);

        vm.prank(USER_1);
        vaultManager.withdraw(0, address(keroseneVault), 50_000 ether, USER_1);
        assertEq(dyadXP.balanceOfNote(0), 30_240_000_000 ether);
        assertEq(dyadXP.accrualRate(0), 50_000 ether);

        skip(7 days);
        assertEq(dyadXP.balanceOfNote(0), 30_240_000_000 ether);

        skip(3.5 days);
        assertEq(dyadXP.balanceOfNote(0), 45_360_000_000 ether);

        skip(3.5 days);
        assertEq(dyadXP.balanceOfNote(0), 30_240_000_000 ether);
        dyadXP.forceUpdateXPBalance(0);

        skip(3.5 days);
        assertEq(dyadXP.balanceOfNote(0), 45_360_000_000 ether);
        dyadXP.forceUpdateXPBalance(0);
        assertEq(dyadXP.balanceOfNote(0), 45_360_000_000 ether);

        skip(3.5 days);
        assertEq(dyadXP.balanceOfNote(0), 30_240_000_000 ether);

        skip(3.5 days);
        assertEq(dyadXP.balanceOfNote(0), 45_360_000_000 ether);

        skip(3.5 days);
        dyadXP.forceUpdateXPBalance(0);
        assertEq(dyadXP.balanceOfNote(0), 30_240_000_000 ether);

        skip(35 days);
        assertEq(dyadXP.balanceOfNote(0), 30_240_000_000 ether);

        skip(3.5 days);
        assertEq(dyadXP.balanceOfNote(0), 45_360_000_000 ether);
        vm.prank(USER_1);
        vaultManager.deposit(0, address(keroseneVault), 150_000 ether);

        skip(3.5 days);
        assertEq(dyadXP.balanceOfNote(0), 52_920_000_000 ether);
        
        vm.stopPrank();
    }

    function test_XPHalving_zeroInitialBalance() public {
        uint256 halvingStart = block.timestamp;
        dyadXP.setHalvingConfiguration(uint40(halvingStart), 2);

        kerosene.transfer(USER_1, 200_000 ether);

        vm.startPrank(USER_1);
        kerosene.approve(address(vaultManager), type(uint256).max);
        vaultManager.deposit(0, address(keroseneVault), 500 ether);
        vm.stopPrank();

        skip(2);
        assertEq(dyadXP.balanceOfNote(0), 500 ether);
        skip(2);
        assertEq(dyadXP.balanceOfNote(0), 750 ether);
        skip(2);
        assertEq(dyadXP.balanceOfNote(0), 875 ether);
        skip(2);
        assertEq(dyadXP.balanceOfNote(0), 937.5 ether);
        skip(2);
        assertEq(dyadXP.balanceOfNote(0), 968.75 ether);
        skip(2);
        assertEq(dyadXP.balanceOfNote(0), 984.375 ether);
        skip(2);
        assertEq(dyadXP.balanceOfNote(0), 992.1875 ether);
        skip(2);
        assertEq(dyadXP.balanceOfNote(0), 996.09375 ether);
        skip(2);
        assertEq(dyadXP.balanceOfNote(0), 998.046875 ether);
    }

    function text_XPHalving_initialBalanceGtRestingValue() public {

    }
}