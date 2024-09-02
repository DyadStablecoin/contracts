// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTestV5} from "./BaseTestV5.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";

contract VaultManagerV5Test is BaseTestV5 {
    using stdStorage for StdStorage;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(USER_1);
        vaultManager.add(0, address(wethVault));

        vm.prank(USER_2);
        vaultManager.add(1, address(wethVault));
    }

    function test_liquidate() public {
        vm.deal(USER_1, 1 ether);
        vm.deal(USER_2, 10 ether);

        _mockOracleResponse(address(wethVault.oracle()), 200000000000, 8);

        vm.startPrank(USER_1);
        vaultManager.authorizeExtension(address(wethGateway), true);
        wethGateway.depositNative{value: 1 ether}(0);
        vaultManager.mintDyad(0, 1000 ether, USER_2);
        vm.stopPrank();

        _mockOracleResponse(address(wethVault.oracle()), 145000000000, 8);

        vm.startPrank(USER_2);
        (address[] memory vaults, uint256[] memory amounts) = vaultManager.liquidate(0, 1, 1000 ether);
        // amount is 0.827586206896551724 WETH
        vm.stopPrank();
        assertEq(vaults.length, 1);
        assertEq(amounts.length, 1);
        assertEq(vaults[0], address(wethVault));
        assertEq(amounts[0], 827586206896551724);

        assertEq(wethVault.id2asset(0), 172413793103448276);
        assertEq(wethVault.id2asset(1), 827586206896551724);
    }
}
