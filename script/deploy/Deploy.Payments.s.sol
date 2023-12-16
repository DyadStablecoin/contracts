// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {Parameters}   from "../../src/params/Parameters.sol";
import {IWETH}        from "../../src/interfaces/IWETH.sol";
import {VaultManager} from "../../src/core/VaultManager.sol";
import {Payments}     from "../../src/periphery/Payments.sol";

contract DeployPayments is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    Payments payments = new Payments(
      VaultManager(address(0)), // TODO: change!!!!!!!
      IWETH(MAINNET_WETH)
    );

    //
    payments.setFee(MAINNET_FEE);
    payments.setFeeRecipient(MAINNET_FEE_RECIPIENT);
    payments.transferOwnership(MAINNET_OWNER);

    vm.stopBroadcast();  // ----------------------------
  }
}
