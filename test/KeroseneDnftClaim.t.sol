// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Test} from "forge-std/Test.sol";
// import {Kerosine} from "../src/staking/Kerosine.sol";
// import {DNft} from "../src/core/DNft.sol";
// import {KeroseneDnftClaim} from "../src/periphery/KeroseneDnftClaim.sol";
// import {Merkle} from "@murky/Merkle.sol";
// import {IERC721} from "forge-std/interfaces/IERC721.sol";

// contract KeroseneDnftClaimTest is Test {
//     DNft dnft;
//     Kerosine kero;
//     KeroseneDnftClaim claim;

//     bytes32[] tree;
//     Merkle m;

//     address constant USER_1 = address(0xabab); // allowlisted, not enough kero
//     address constant USER_2 = address(0xcdcd); // allowlisted, has enough kero
//     address constant USER_3 = address(0xefef); // not allowlisted, has kero

//     function setUp() external {
//         kero = new Kerosine();
//         dnft = new DNft();
//         claim = new KeroseneDnftClaim(address(dnft), address(kero), 100_000 ether, 0x0);

//         dnft.mintInsiderNft(address(claim));
//         dnft.mintInsiderNft(address(claim));
//         dnft.mintInsiderNft(address(claim));

//         kero.transfer(USER_1, 10_000 ether);
//         kero.transfer(USER_2, 250_000 ether);
//         kero.transfer(USER_3, 250_000 ether);

//         tree.push(keccak256(abi.encode(USER_1)));
//         tree.push(keccak256(abi.encode(USER_2)));

//         m = new Merkle();
//         bytes32 root = m.getRoot(tree);
//         vm.prank(claim.owner());
//         claim.setMerkleRoot(root);
//     }

//     function test_buyNote_success() external {
//         bytes32[] memory proof = m.getProof(tree, 1);
//         vm.startPrank(USER_2);
        
//         kero.approve(address(claim), 250_000 ether);
//         vm.expectEmit(true, true, true, false);
//         emit IERC721.Transfer(address(claim), USER_2, 2);
//         claim.buyNote(proof);
        
//         vm.stopPrank();

//         assertEq(dnft.balanceOf(USER_2), 1);
//     }

//     function test_buyTwice_reverts() external {
//         bytes32[] memory proof = m.getProof(tree, 1);
//         vm.startPrank(USER_2);
        
//         kero.approve(address(claim), 250_000 ether);
//         claim.buyNote(proof);
//         vm.expectRevert(KeroseneDnftClaim.AlreadyPurchased.selector);
//         claim.buyNote(proof);
        
//         vm.stopPrank();

//         assertEq(dnft.balanceOf(USER_2), 1);
        
//     }

//     function test_notEnoughKerosense_reverts() external {
//         bytes32[] memory proof = m.getProof(tree, 0);
//         vm.startPrank(USER_1);
        
//         kero.approve(address(claim), 250_000 ether);
//         vm.expectRevert();
//         claim.buyNote(proof);

//         vm.stopPrank();
//     }

//     function test_notWhitelisted_reverts() external {
//         bytes32[] memory proof = m.getProof(tree, 0);
//         vm.startPrank(USER_3);

//         kero.approve(address(claim), 250_000 ether);
//         vm.expectRevert(KeroseneDnftClaim.InvalidProof.selector);
//         claim.buyNote(proof);

//         vm.stopPrank();
//     }
// }
