// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {KeroseneVault} from "../../src/core/VaultKerosene.sol";
import {KeroseneOracleV2} from "../../src/core/KeroseneOracleV2.sol";
import {VaultManager}  from "../../src/core/VaultManager.sol";
import {KerosineManager}  from "../../src/core/KerosineManager.sol";
import {Dyad}  from "../../src/core/Dyad.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";
import {IWstETH} from "../../src/interfaces/IWstETH.sol";
import {KerosineDenominator}    from "../../src/staking/KerosineDenominator.sol";
import {Kerosine}               from "../../src/staking/Kerosine.sol";
import {Parameters}             from "../../src/params/Parameters.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployVault is Script, Parameters {
  function run() public {
    vm.startBroadcast();  // ----------------------

    KeroseneOracleV2 oracle = new KeroseneOracleV2();

    KerosineDenominator kerosineDenominator = new KerosineDenominator(
      Kerosine(MAINNET_KEROSENE)
    );

    new KeroseneVault(
      VaultManager   (0xB62bdb1A6AC97A9B70957DD35357311e8859f0d7), 
      ERC20          (0xf3768D6e78E65FC64b8F12ffc824452130BD5394), 
      Dyad           (0xFd03723a9A3AbE0562451496a9a394D2C4bad4ab), 
      KerosineManager(0xFCCF9d9466ED79AFeD2ABc46350bFb78f7B47b90), 
      oracle, 
      kerosineDenominator
    );

    vm.stopBroadcast();  // ----------------------------
  }
}

