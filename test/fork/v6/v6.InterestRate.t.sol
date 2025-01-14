// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Parameters} from "../../../src/params/Parameters.sol";

import {KeroseneValuer} from "../../../src/staking/KeroseneValuer.sol";
import {Kerosine} from "../../../src/staking/Kerosine.sol";
import {KerosineManager} from "../../../src/core/KerosineManager.sol";
import {VaultManagerV6} from "../../../src/core/VaultManagerV6.sol";
import {Dyad} from "../../../src/core/Dyad.sol";
import {VaultLicenser} from "../../../src/core/VaultLicenser.sol";
import {Licenser} from "../../../src/core/Licenser.sol";
import {VaultGCoin} from "../../mocks/Vault.GCoin.sol";
import {DNft} from "../../../src/core/DNft.sol";
import {InterestVault} from "../../../src/core/InterestVault.sol";

contract InterestRateTest is Test, Parameters {
    VaultManagerV6 manager;
    VaultGCoin mockVault;
    Dyad dyad;

    address alice = makeAddr("ALICE");
    uint256 aliceNoteID;
    address bob = makeAddr("BOB");
    uint256 bobNoteID;

    function setUp() external {
        vm.createSelectFork(vm.envString("RPC_URL"), 21_431_383);

        mockVault = new VaultGCoin(address(this), MAINNET_V2_VAULT_MANAGER, MAINNET_DNFT);

        manager = VaultManagerV6(MAINNET_V2_VAULT_MANAGER);
        dyad = Dyad(MAINNET_V2_DYAD);

        KeroseneValuer keroseneValuer = new KeroseneValuer(
            Kerosine(MAINNET_KEROSENE), KerosineManager(MAINNET_V2_KEROSENE_MANAGER), Dyad(MAINNET_V2_DYAD)
        );

        InterestVault interestVault = new InterestVault(address(this), MAINNET_V2_DYAD, MAINNET_V2_VAULT_MANAGER);

        vm.startPrank(MAINNET_FEE_RECIPIENT);

        dyad.licenser().add(address(interestVault));
        VaultLicenser(MAINNET_V2_VAULT_LICENSER).add(address(mockVault), false);

        vm.stopPrank();

        bobNoteID = _mintNote(bob);
        _depositToVault(bobNoteID, 1_000_000e18);
        _mintDyad(bobNoteID, 1_000e18);

        vm.startPrank(MAINNET_FEE_RECIPIENT);

        VaultManagerV6 impl = new VaultManagerV6();
        VaultManagerV6(MAINNET_V2_VAULT_MANAGER).upgradeToAndCall(
            address(impl),
            abi.encodeWithSelector(impl.initialize.selector, address(keroseneValuer), address(interestVault))
        );

        manager.setInterestRate(100);

        vm.stopPrank();

        aliceNoteID = _mintNote(alice);
    }

    function testInterestRateCanBeUpdated() external {
        uint256 currentInterestRate = manager.interestRate();

        vm.prank(MAINNET_FEE_RECIPIENT);
        manager.setInterestRate(400);

        assertGt(manager.interestRate(), currentInterestRate);
    }

    function testInterestRateCantGoAboveMax() external {
        vm.expectRevert(VaultManagerV6.InterestRateTooHigh.selector);
        vm.prank(MAINNET_FEE_RECIPIENT);
        manager.setInterestRate(5000);
    }

    function testSetMaxInterestRate() external {
        vm.prank(MAINNET_FEE_RECIPIENT);
        manager.setMaxInterestRate(100);

        assertEq(manager.maxInterestRateInBps(), 100);

        vm.expectRevert(VaultManagerV6.InterestRateTooHigh.selector);
        vm.prank(MAINNET_FEE_RECIPIENT);
        manager.setInterestRate(101);
    }

    function testInterestIndexIsUpdated() external {
        uint256 globalActiveInterestIndexSnapshot = manager.activeInterestIndex();
        uint256 aliceInterestIndexSnapshot = manager.noteInterestIndex(aliceNoteID);

        assertEq(globalActiveInterestIndexSnapshot, 1e27);
        assertEq(aliceInterestIndexSnapshot, 0);

        _depositToVault(aliceNoteID, 1_000e18);

        assertEq(manager.activeInterestIndex(), globalActiveInterestIndexSnapshot);
        assertEq(manager.noteInterestIndex(aliceNoteID), manager.activeInterestIndex());

        globalActiveInterestIndexSnapshot = manager.activeInterestIndex();
        aliceInterestIndexSnapshot = manager.noteInterestIndex(aliceNoteID);

        vm.warp(vm.getBlockTimestamp() + 12 seconds);
        vm.roll(vm.getBlockNumber() + 1);

        _withdrawFromVault(aliceNoteID, 100e18);

        assertGt(manager.activeInterestIndex(), globalActiveInterestIndexSnapshot);
        assertEq(manager.noteInterestIndex(aliceNoteID), manager.activeInterestIndex());

        globalActiveInterestIndexSnapshot = manager.activeInterestIndex();
        aliceInterestIndexSnapshot = manager.noteInterestIndex(aliceNoteID);
    }

    function testInterestAccrues() external {
        uint256 dyadToMint = 10e18;

        _depositToVault(aliceNoteID, 1_000e18);
        _mintDyad(aliceNoteID, dyadToMint);

        assertEq(manager.getNoteDebt(aliceNoteID), dyadToMint);

        vm.warp(vm.getBlockTimestamp() + 365 days);

        assertApproxEqRel(manager.getNoteDebt(aliceNoteID), (dyadToMint * 101) / 100, 1e10);
        assertApproxEqRel(manager.getTotalDebt(), (dyad.totalSupply() * 101) / 100, 1e10);
    }

    function testInterestCanBeClaimed() external {
        uint256 dyadToMint = 10e18;

        _depositToVault(aliceNoteID, 1_000e18);
        _mintDyad(aliceNoteID, dyadToMint);

        assertEq(manager.getNoteDebt(aliceNoteID), dyadToMint);

        vm.warp(vm.getBlockTimestamp() + 365 days);

        uint256 claimableInterest = manager.claimableInterest();

        vm.prank(MAINNET_FEE_RECIPIENT);
        uint256 claimedInterest = manager.claimInterest();

        assertEq(claimedInterest, claimableInterest);

        assertEq(manager.claimableInterest(), 0);
    }

    function testRepayDebt() external {
        uint256 dyadToMint = 10e18;

        _depositToVault(aliceNoteID, 1_000e18);
        assertEq(manager.noteInterestIndex(aliceNoteID), manager.activeInterestIndex());

        _mintDyad(aliceNoteID, dyadToMint);

        _repayDebt(aliceNoteID, dyadToMint);

        assertEq(manager.getNoteDebt(aliceNoteID), 0);
        assertEq(dyad.mintedDyad(aliceNoteID), 0);
        assertEq(manager.noteInterestIndex(aliceNoteID), 0);
    }

    function testRepayDebtWithInterests() external {
        uint256 dyadToMint = 10e18;

        _depositToVault(aliceNoteID, 1_000e18);
        assertEq(manager.noteInterestIndex(aliceNoteID), manager.activeInterestIndex());

        _mintDyad(aliceNoteID, dyadToMint);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        uint256 noteDebt = manager.getNoteDebt(aliceNoteID);

        // interests accrued
        assertGt(noteDebt, dyadToMint);

        // bob gives some dyad to alice
        vm.prank(bob);
        dyad.transfer(alice, dyadToMint);

        // alice pays the whole debt
        _repayDebt(aliceNoteID, noteDebt);

        assertEq(manager.getNoteDebt(aliceNoteID), 0);
        assertEq(dyad.mintedDyad(aliceNoteID), 0);
        assertEq(manager.noteInterestIndex(aliceNoteID), 0);
    }

    function testRepayWholeDebtWithInterests() external {
        uint256 dyadToMint = 10e18;

        _depositToVault(aliceNoteID, 1_000e18);
        _mintDyad(aliceNoteID, dyadToMint);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        uint256 noteDebt = manager.getNoteDebt(aliceNoteID);

        // interests accrued
        assertGt(noteDebt, dyadToMint);

        // bob gives some dyad to alice
        vm.prank(bob);
        dyad.transfer(alice, dyadToMint);

        // alice pays the whole debt
        _repayDebt(aliceNoteID, type(uint256).max);

        assertEq(manager.getNoteDebt(aliceNoteID), 0);
        assertEq(dyad.mintedDyad(aliceNoteID), 0);
        assertEq(manager.noteInterestIndex(aliceNoteID), 0);
    }

    function testRepayOldUserDebt() external {
        _repayDebt(bobNoteID, 1_000e18);

        assertEq(manager.getNoteDebt(bobNoteID), 0);
        assertEq(dyad.mintedDyad(bobNoteID), 0);
        assertEq(manager.noteInterestIndex(bobNoteID), 0);
    }

    function testRepayOldUserDebtWithInterest() external {
        uint256 mintedDyad = dyad.mintedDyad(bobNoteID);
        uint256 noteDebt = manager.getNoteDebt(bobNoteID);

        // interest have not accrued yet
        assertEq(noteDebt, mintedDyad);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        noteDebt = manager.getNoteDebt(bobNoteID);

        _depositToVault(aliceNoteID, 1_000_000e18);
        _mintDyad(aliceNoteID, mintedDyad);

        // alice sends some dyad to bob to repay the debt
        vm.prank(alice);
        dyad.transfer(bob, mintedDyad);

        // interest have accrued
        assertGt(noteDebt, mintedDyad);

        _repayDebt(bobNoteID, noteDebt);

        assertEq(manager.getNoteDebt(bobNoteID), 0);
        assertEq(dyad.mintedDyad(bobNoteID), 0);
        assertEq(manager.noteInterestIndex(bobNoteID), 0);
    }

    function testInterestAccruesForOldUserWithNoInteraction() external {
        uint256 initialDebt = dyad.mintedDyad(bobNoteID);

        assertEq(manager.getNoteDebt(bobNoteID), initialDebt);

        vm.warp(vm.getBlockTimestamp() + 1 hours);
        assertGt(manager.getNoteDebt(bobNoteID), initialDebt);
    }

    function testNoteInterestIndexUpdates() external {
        uint256 initialDebt = 10e18;

        _depositToVault(aliceNoteID, 1_000_000e18);
        _mintDyad(aliceNoteID, initialDebt);

        assertEq(manager.noteInterestIndex(aliceNoteID), manager.activeInterestIndex());

        _repayDebt(aliceNoteID, initialDebt);

        assertEq(manager.noteInterestIndex(aliceNoteID), 0);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        _mintDyad(aliceNoteID, initialDebt);

        assertEq(manager.noteInterestIndex(aliceNoteID), manager.activeInterestIndex());

        vm.warp(vm.getBlockTimestamp() + 1 days);

        _repayDebt(bob, aliceNoteID, manager.getNoteDebt(aliceNoteID));

        assertEq(manager.noteInterestIndex(aliceNoteID), 0);
    }

    function testStateIsUpdatedForOldUsers() external {
        // for old users that have not interacted with the protocol after interest rates were added
        // the interest index and note debt should be 0
        assertEq(manager.noteInterestIndex(bobNoteID), 0);

        _depositToVault(bobNoteID, 1);

        // after an interaction the note interest index should be set to the initial interest index
        assertEq(manager.noteInterestIndex(bobNoteID), manager.INTEREST_PRECISION());
    }

    function _mintNote(address _to) internal returns (uint256) {
        deal(_to, 10 ether);

        vm.prank(_to);

        return DNft(MAINNET_DNFT).mintNft{value: 10 ether}(_to);
    }

    function _mintDyad(uint256 _noteID, uint256 _amount) internal {
        address owner = DNft(MAINNET_DNFT).ownerOf(_noteID);

        vm.startPrank(owner);

        manager.mintDyad(_noteID, _amount, owner);

        vm.stopPrank();
    }

    function _depositToVault(uint256 _noteID, uint256 _amount) internal {
        address owner = DNft(MAINNET_DNFT).ownerOf(_noteID);

        mockVault.mintAsset(owner, _amount);

        vm.startPrank(owner);

        manager.add(_noteID, address(mockVault));
        mockVault.asset().approve(address(manager), _amount);
        manager.deposit(_noteID, address(mockVault), _amount);

        vm.stopPrank();
    }

    function _withdrawFromVault(uint256 _noteID, uint256 _amount) internal {
        address owner = DNft(MAINNET_DNFT).ownerOf(_noteID);

        vm.startPrank(owner);

        manager.withdraw(_noteID, address(mockVault), _amount, owner);

        vm.stopPrank();
    }

    function _repayDebt(uint256 _noteID, uint256 _amount) internal {
        address owner = DNft(MAINNET_DNFT).ownerOf(_noteID);

        _repayDebt(owner, _noteID, _amount);
    }

    function _repayDebt(address _from, uint256 _noteID, uint256 _amount) internal {
        vm.startPrank(_from);

        manager.burnDyad(_noteID, _amount);

        vm.stopPrank();
    }
}
