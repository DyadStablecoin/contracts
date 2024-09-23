// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTestV5} from "./BaseTestV5.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {RedeemCollateralExtension} from "../../src/periphery/RedeemCollateralExtension.sol";

contract RedeemCollateralExtensionTest is BaseTestV5 {
    using stdStorage for StdStorage;

    RedeemCollateralExtension redeemer;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(USER_1);
        vaultManager.add(0, address(wethVault));

        redeemer = new RedeemCollateralExtension(address(dyad), address(dNft), address(vaultManager));

        vaultManager.authorizeSystemExtension(address(redeemer), true);
    }

    function test_redeem() public {
        vm.pauseGasMetering();
        _setupDepositAndMintDyad();
        vm.startPrank(USER_1);
        vaultManager.authorizeExtension(address(redeemer), true);
        dyad.approve(address(redeemer), type(uint256).max);
        vm.stopPrank();
        vm.resumeGasMetering();

        vm.startPrank(USER_1);
        redeemer.redeemDyad(0, address(wethVault), 1000 ether, USER_1);
        vm.stopPrank();

        assertEq(weth.balanceOf(address(wethVault)), 0.5 ether);
        assertEq(wethVault.id2asset(0), 0.5 ether);
        assertEq(weth.balanceOf(USER_1), 0.5 ether);
        assertEq(dyad.balanceOf(USER_1), 0);
    }

    function test_redeem_extensionNotApproved_reverts() public {
        vm.pauseGasMetering();
        _setupDepositAndMintDyad();
        vm.prank(USER_1);
        dyad.approve(address(redeemer), type(uint256).max);
        vm.resumeGasMetering();

        vm.startPrank(USER_1);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        redeemer.redeemDyad(0, address(wethVault), 1000 ether, USER_1);
        vm.stopPrank();
    }

    function test_redeem_dyadNotApproved_reverts() public {
        vm.pauseGasMetering();
        _setupDepositAndMintDyad();
        vm.prank(USER_1);
        vaultManager.authorizeExtension(address(redeemer), true);
        vm.stopPrank();
        vm.resumeGasMetering();

        vm.startPrank(USER_1);
        vm.expectRevert();
        redeemer.redeemDyad(0, address(wethVault), 1000 ether, USER_1);
        vm.stopPrank();
    }

    function _setupDepositAndMintDyad() internal {
        _mockOracleResponse(address(wethVault.oracle()), 200000000000, 8);
        vm.deal(USER_1, 1 ether);
        vm.startPrank(USER_1);
        weth.deposit{value: 1 ether}();
        weth.approve(address(vaultManager), 1 ether);
        vaultManager.deposit(0, address(wethVault), 1 ether);
        vaultManager.mintDyad(0, 1000 ether, USER_1);
        vm.stopPrank();

        vm.roll(vm.getBlockNumber() + 1);
    }
}
