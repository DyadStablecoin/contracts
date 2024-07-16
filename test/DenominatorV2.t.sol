// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Kerosine} from "../src/staking/Kerosine.sol";
import {KerosineDenominatorV2} from "../src/staking/KerosineDenominatorV2.sol";

contract KerosineDenominatorV2Test is Test {

    Kerosine kero;
    KerosineDenominatorV2 denominator;

    function setUp() external {
        kero = new Kerosine();
        denominator = new KerosineDenominatorV2(kero);

        kero.transfer(denominator.owner(), 100_000_000 ether);
        kero.transfer(0x3962f6585946823440d274aD7C719B02b49DE51E, 30_000 ether);
    }

    function test_denominator() external {
        assertLt(denominator.denominator(), kero.totalSupply());

        assertEq(denominator.denominator(), 1_000_000_000 ether - 30_000 ether - 100_000_000 ether);
    }
}
