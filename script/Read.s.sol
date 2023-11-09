// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IDNft} from "../src/interfaces/IDNft.sol";
import {Dyad} from "../src/core/Dyad.sol";

contract Read is Script {
  function run() public {

//     console.log("block number:", block.number);
//     console.log();

//     IDNft dNft = IDNft(0xeC182DefC3Bb9d3D87A635375F23111080DFfeDb);
//     console.log("dNft total supply: ", dNft.totalSupply());
//     console.log("dNft ETH balance: ", address(dNft).balance);
//     console.log("dNft maxXp: ", dNft.maxXp());
//     console.log("dNft totalXp: ", dNft.totalXp());
//     console.log("dNft totalDeposit: ");
//     console.logInt( dNft.totalDeposit());
//     console.log("dNft dyadDelta: ");
//     console.logInt(dNft.dyadDelta());
//     console.log("dNft prevDyadDelta: ");
//     console.logInt(dNft.prevDyadDelta());
//     console.log("dNft ethPrice: ");
//     console.log(dNft.ethPrice());
//     console.log("dNft syncedBlock: ", dNft.syncedBlock());
//     console.log("dNft prevSyncedBlock: ", dNft.prevSyncedBlock());

//     Dyad dyad = Dyad(0xeC182DefC3Bb9d3D87A635375F23111080DFfeDb);
//     console.log("");
//     console.log("dyad total supply: ", dyad.totalSupply());
  
//     uint id = 11;
//     console.log("");
//     console.log("dNFT id: ", id);

//     console.log("xp: ", dNft.idToNft(id).xp);
//     console.log("withdrawal: ", dNft.idToNft(id).withdrawal);
//     console.log("deposit");
//     console.logInt(dNft.idToNft(id).deposit);
  }
}
