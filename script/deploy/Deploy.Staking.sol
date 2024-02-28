// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {Kerosine}   from "../../src/staking/Kerosine.sol";
import {Staking}    from "../../src/staking/Staking.sol";
import {Parameters} from "../../src/params/Parameters.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployStaking is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    Kerosine kerosine = new Kerosine();
    Staking  staking  = new Staking(ERC20(MAINNET_WETH_DYAD_UNI), kerosine);
    kerosine.transfer(address(staking), kerosine.totalSupply());

    vm.stopBroadcast();  // ----------------------------
  }
}
