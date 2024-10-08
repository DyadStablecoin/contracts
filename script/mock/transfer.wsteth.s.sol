// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract Transfer is Script {
    address TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address RECIPIENT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 AMOUNT = 200e18;

    function run() public {
        vm.startBroadcast(); // ----------------------

        ERC20 token = ERC20(TOKEN);
        token.transfer(RECIPIENT, AMOUNT);

        vm.stopBroadcast(); // ----------------------------

        console.log("balance of recipient", token.balanceOf(RECIPIENT));
    }
}
