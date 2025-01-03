// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DNft} from "../../src/core/DNft.sol";
import {FreeNoteMinter} from "../../src/core/FreeNoteMinter.sol";
import {Parameters} from "../../src/params/Parameters.sol";

contract FreeNoteMinterTest is Test, Parameters {
    DNft dnft;
    FreeNoteMinter minter;

    address OWNER = makeAddr("OWNER");
    address ALICE = makeAddr("ALICE");

    function setUp() external {
        vm.createSelectFork(vm.envString("RPC_URL"), 21_086_097);

        dnft = DNft(MAINNET_DNFT);

        vm.prank(OWNER);
        minter = new FreeNoteMinter(address(dnft));

        deal(address(minter), 10e18);

        vm.prank(dnft.owner());
        dnft.transferOwnership(address(minter));
    }

    function testItCanMint() external {
        uint256 minterBalanceSnapshot = address(minter).balance;
        uint256 dnftBalanceSnapshot = address(dnft).balance;

        vm.prank(ALICE);
        uint256 noteID = minter.mint();

        assertEq(dnft.ownerOf(noteID), ALICE);
        assertEq(address(minter).balance, minterBalanceSnapshot + dnftBalanceSnapshot);
    }

    function testBalanceCanBeRecovered() external {
        uint256 ownerBalance = OWNER.balance;
        uint256 minterBalance = address(minter).balance;

        assertGt(minterBalance, 0);

        vm.prank(OWNER);
        minter.recoverEth();

        assertEq(address(minter).balance, 0);
        assertEq(OWNER.balance, ownerBalance + minterBalance);
    }

    function testBalanceCanBeRecoveredOnlyByOwner() external {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(ALICE);
        minter.recoverEth();
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
