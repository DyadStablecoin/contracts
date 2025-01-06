// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DNft} from "../../src/core/DNft.sol";
import {KeroseneNoteMinter} from "../../src/core/KeroseneNoteMinter.sol";
import {Kerosine} from "../../src/staking/Kerosine.sol";
import {Parameters} from "../../src/params/Parameters.sol";

contract KeroNoteMinterTest is Test, Parameters {
    DNft dnft;
    KeroseneNoteMinter minter;
    Kerosine kero;

    address OWNER = makeAddr("OWNER");
    address ALICE = makeAddr("ALICE");

    function setUp() external {
        vm.createSelectFork(vm.envString("RPC_URL"), 21_086_097);

        dnft = DNft(MAINNET_DNFT);

        kero = Kerosine(MAINNET_KEROSENE);

        vm.prank(OWNER);
        minter = new KeroseneNoteMinter(address(kero), address(dnft));

        deal(address(minter), 10e18);
        deal(address(kero), address(ALICE), 1_000_000e18);

        vm.prank(dnft.owner());
        dnft.transferOwnership(address(minter));
    }

    function testPriceCanBeChanged() external {
        uint256 newPrice = 20e18;

        vm.prank(OWNER);
        minter.setPrice(newPrice);

        assertEq(minter.price(), newPrice);
    }

    function testPriceCanBeChangedOnlyByOwner() external {
        uint256 newPrice = 20e18;

        vm.expectRevert("UNAUTHORIZED");
        vm.prank(ALICE);
        minter.setPrice(newPrice);
    }

    function testItCanMint() external {
        uint256 minterBalanceSnapshot = address(minter).balance;
        uint256 dnftBalanceSnapshot = address(dnft).balance;
        uint256 burnAddressKeroBalanceSnapshot = kero.balanceOf(minter.BURN_ADDRESS());

        vm.startPrank(ALICE);

        kero.approve(address(minter), minter.price());
        uint256 noteID = minter.mint();

        vm.stopPrank();

        assertEq(dnft.ownerOf(noteID), ALICE);
        assertEq(address(minter).balance, minterBalanceSnapshot + dnftBalanceSnapshot);
        assertEq(kero.balanceOf(minter.BURN_ADDRESS()), burnAddressKeroBalanceSnapshot + minter.price());
    }

    function testItCanFreeMint() external {
        uint256 minterBalanceSnapshot = address(minter).balance;
        uint256 dnftBalanceSnapshot = address(dnft).balance;
        uint256 burnAddressKeroBalanceSnapshot = kero.balanceOf(minter.BURN_ADDRESS());

        vm.prank(OWNER);
        minter.setPrice(0);

        vm.startPrank(ALICE);

        uint256 noteID = minter.mint();

        vm.stopPrank();

        assertEq(dnft.ownerOf(noteID), ALICE);
        assertEq(address(minter).balance, minterBalanceSnapshot + dnftBalanceSnapshot);
        assertEq(kero.balanceOf(minter.BURN_ADDRESS()), burnAddressKeroBalanceSnapshot);
    }

    function testBalanceCanBeRecovered() external {
        uint256 ownerBalance = OWNER.balance;
        uint256 minterBalance = address(minter).balance;

        assertGt(minterBalance, 0);

        vm.prank(OWNER);
        minter.drain();

        assertEq(address(minter).balance, 0);
        assertEq(OWNER.balance, ownerBalance + minterBalance);
    }

    function testBalanceCanBeRecoveredOnlyByOwner() external {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(ALICE);
        minter.drain();
    }

    function testDNftOwnershipCanBeTransferred() external {
        vm.prank(OWNER);
        minter.transferDNftOwnership(ALICE);

        assertEq(dnft.owner(), ALICE);
    }

    function testDNftOwnershipCanBeTransferredOnlyByOwner() external {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(ALICE);
        minter.transferDNftOwnership(ALICE);
    }
}
