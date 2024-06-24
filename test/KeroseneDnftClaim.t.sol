// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Kerosine} from "../src/staking/Kerosine.sol";
import {DNft} from "../src/core/DNft.sol";
import {KeroseneDnftClaim} from "../src/periphery/KeroseneDnftClaim.sol";

contract KeroseneDnftClaimTest is Test {
    DNft dnft;
    Kerosine kero;
    KeroseneDnftClaim claim;

    address constant USER_1 = address(0xabab); // allowlisted, not enough kero
    address constant USER_2 = address(0xcdcd); // allowlisted, has enough kero
    address constant USER_3 = address(0xefef); // not allowlisted, has kero

    function setUp() external {
        kero = new Kerosine();
        dnft = new DNft();
        claim = new KeroseneDnftClaim(address(dnft), address(kero), 100_000 ether, 0x0);

        kero.transfer(USER_1, 10_000 ether);
        kero.transfer(USER_2, 250_000 ether);
        kero.transfer(USER_3, 250_000 ether);
    }

    function buyNoteWithKeroseneSuccess() external {
        
    }
}
