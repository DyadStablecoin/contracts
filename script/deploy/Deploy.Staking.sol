// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {Kerosine}   from "../../src/staking/Kerosine.sol";
import {Staking}    from "../../src/staking/Staking.sol";
import {Parameters} from "../../src/params/Parameters.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployStaking is Script, Parameters {
  function run() public {

    uint ONE_MILLION = 1_000_000;

    vm.startBroadcast();  // ----------------------

    Kerosine kerosine = new Kerosine();
    Staking  staking  = new Staking(ERC20(MAINNET_WETH_DYAD_UNI), kerosine);

    kerosine.transfer(
      address(staking),
      ONE_MILLION * 10**18 // 1 million
    );

    kerosine.transfer(
      MAINNET_OWNER,                                // multi-sig
      kerosine.totalSupply() - ONE_MILLION * 10**18 // the rest
    );

    vm.stopBroadcast();  // ----------------------------
  }
}
