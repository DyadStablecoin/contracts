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

        VaultManagerV6 impl = new VaultManagerV6();
        VaultManagerV6(MAINNET_V2_VAULT_MANAGER).upgradeToAndCall(
            address(impl),
            abi.encodeWithSelector(impl.initialize.selector, address(keroseneValuer), address(interestVault))
        );

        manager.setInterestRate(100);

        vm.stopPrank();

        aliceNoteID = _mintNote(alice);
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
}
