// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {Parameters}   from "../../src/params/Parameters.sol";
import {VaultManager} from "../../src/core/VaultManager.sol";
import {DNft}         from "../../src/core/DNft.sol";
import {Dyad}         from "../../src/core/Dyad.sol";
import {Licenser}     from "../../src/core/Licenser.sol";
import {Vault}        from "../../src/core/Vault.sol";
import {VaultWstEth}  from "../../src/core/Vault.wsteth.sol";
import {Payments}     from "../../src/periphery/Payments.sol";
import {IWETH}        from "../../src/interfaces/IWETH.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployV2 is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    Licenser vaultLicenser = new Licenser();

    // Vault Manager needs to be licensed
    VaultManager vaultManager = new VaultManager(
      DNft(MAINNET_DNFT),
      Dyad(MAINNET_DYAD),
      Licenser(vaultLicenser)
    );

    // weth vault
    Vault vault = new Vault(
      vaultManager,
      ERC20(MAINNET_WETH),
      IAggregatorV3(MAINNET_WETH_ORACLE)
    );

    // wsteth vault
    new VaultWstEth(
      vaultManager, 
      ERC20        (MAINNET_WSTETH), 
      IAggregatorV3(MAINNET_CHAINLINK_STETH)
    );

    // vaults need to be licensed!

    Payments payments = new Payments(
      vaultManager,
      IWETH(MAINNET_WETH)
    );

    payments.setFee(MAINNET_FEE);
    payments.setFeeRecipient(MAINNET_FEE_RECIPIENT);

    vm.stopBroadcast();  // ----------------------------
  }
}
