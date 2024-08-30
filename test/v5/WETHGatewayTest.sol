// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTestV5 } from "./BaseTestV5.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";

contract WETHGatewayTest is BaseTestV5 {
    using stdStorage        for StdStorage;

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

        vm.startPrank(USER_1);
        wethGateway.withdrawNative(0, 1 ether, USER_1);
        vm.stopPrank();

        assertEq(weth.balanceOf(address(wethVault)), 0);
        assertEq(wethVault.id2asset(0), 0);
        assertEq(weth.balanceOf(USER_1), 0);
        assertEq(USER_1.balance, 1 ether);
    }
}