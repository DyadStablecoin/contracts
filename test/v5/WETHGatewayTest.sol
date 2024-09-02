// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTestV5} from "./BaseTestV5.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";

contract WETHGatewayTest is BaseTestV5 {
    using stdStorage for StdStorage;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(USER_1);
        vaultManager.add(0, address(wethVault));
    }

    function test_wethGatewayDeposit() public {
        vm.deal(USER_1, 1 ether);
        vm.startPrank(USER_1);
        vaultManager.authorizeExtension(address(wethGateway), true);
        wethGateway.depositNative{value: 1 ether}(0);
        vm.stopPrank();

        assertEq(weth.balanceOf(address(wethVault)), 1 ether);
        assertEq(wethVault.id2asset(0), 1 ether);
    }

    function test_wethGatewayWithdraw() public {
        vm.pauseGasMetering();
        test_wethGatewayDeposit();
        vm.resumeGasMetering();
        vm.roll(block.number + 1);

        _mockOracleResponse(address(wethVault.oracle()), 200000000000, 8);

        vm.startPrank(USER_1);
        wethGateway.withdrawNative(0, 1 ether, USER_1);
        vm.stopPrank();

        assertEq(weth.balanceOf(address(wethVault)), 0);
        assertEq(wethVault.id2asset(0), 0);
        assertEq(weth.balanceOf(USER_1), 0);
        assertEq(USER_1.balance, 1 ether);
    }

    function test_wethGatewayRedeem() public {
        vm.pauseGasMetering();
        test_wethGatewayDeposit();
        vm.resumeGasMetering();
        vm.roll(block.number + 1);

        _mockOracleResponse(address(wethVault.oracle()), 200000000000, 8);

        vm.startPrank(USER_1);
        dyad.approve(address(wethGateway), 1000 ether);
        vaultManager.mintDyad(0, 1000 ether, USER_1);
        wethGateway.redeemNative(0, 1000 ether, USER_1);
        vm.stopPrank();

        assertEq(weth.balanceOf(address(wethVault)), 0.5 ether);
        assertEq(wethVault.id2asset(0), 0.5 ether);
        assertEq(weth.balanceOf(USER_1), 0);
        assertEq(dyad.balanceOf(USER_1), 0);
        assertEq(USER_1.balance, 0.5 ether);
    }
}
