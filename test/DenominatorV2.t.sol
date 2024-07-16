// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Kerosine} from "../src/staking/Kerosine.sol";
import {KerosineDenominatorV2} from "../src/staking/KerosineDenominatorV2.sol";

contract KerosineDenominatorV2Test is Test {

    Kerosine kero;
    KerosineDenominatorV2 denominator;

    address constant TEST_ADDR_1 = address(0xabab);

    function setUp() external {
        kero = new Kerosine();
        denominator = new KerosineDenominatorV2(kero);

        kero.transfer(denominator.owner(), 100_000_000 ether);
        kero.transfer(0x3962f6585946823440d274aD7C719B02b49DE51E, 30_000 ether);
        kero.transfer(TEST_ADDR_1, 150_000 ether);
    }

    function test_denominator() external {
        assertLt(denominator.denominator(), kero.totalSupply());

        assertEq(denominator.denominator(), 1_000_000_000 ether - 30_000 ether - 100_000_000 ether);
    }

    function test_denominator_setExcluded() external {

        uint256 totalSupply = kero.totalSupply();
        uint256 denominatorValue = denominator.denominator();

        vm.prank(denominator.owner());
        denominator.setAddressExcluded(TEST_ADDR_1, true);

        assertEq(denominator.denominator(), denominatorValue - kero.balanceOf(TEST_ADDR_1));
    }

    function test_denominator_setExcluded_notOwner_reverts() external {
        vm.expectRevert("UNAUTHORIZED");
        denominator.setAddressExcluded(TEST_ADDR_1, true);
    }

    function test_denominator_isExcludedAddress() external {
        assertFalse(denominator.isExcludedAddress(TEST_ADDR_1));
        vm.prank(denominator.owner());
        denominator.setAddressExcluded(TEST_ADDR_1, true);
        assertTrue(denominator.isExcludedAddress(TEST_ADDR_1));
    }

    function test_denominator_getExcludedAddresses() external {
        address[] memory excludedAddresses = denominator.excludedAddresses();
        assertEq(excludedAddresses.length, 2);
        assertEq(excludedAddresses[0], 0xDeD796De6a14E255487191963dEe436c45995813);
        assertEq(excludedAddresses[1], 0x3962f6585946823440d274aD7C719B02b49DE51E);

        vm.prank(denominator.owner());
        denominator.setAddressExcluded(TEST_ADDR_1, true);

        excludedAddresses = denominator.excludedAddresses();
        assertEq(excludedAddresses.length,3);
        assertEq(excludedAddresses[0], 0xDeD796De6a14E255487191963dEe436c45995813);
        assertEq(excludedAddresses[1], 0x3962f6585946823440d274aD7C719B02b49DE51E);
        assertEq(excludedAddresses[2], TEST_ADDR_1);
    }

    function test_denominator_setIncluded() external {
        address[] memory excludedAddresses = denominator.excludedAddresses();
        for (uint i = 0; i < excludedAddresses.length; i++) {
            vm.prank(denominator.owner());
            denominator.setAddressExcluded(excludedAddresses[i], false);
        }
        assertEq(denominator.excludedAddresses().length, 0);
        assertEq(denominator.denominator(), kero.totalSupply());
    }
}
