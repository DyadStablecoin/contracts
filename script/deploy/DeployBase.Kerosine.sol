// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {KerosineManager}        from "../../src/core/KerosineManager.sol";
import {UnboundedKerosineVault} from "../../src/core/Vault.kerosine.unbounded.sol";
import {BoundedKerosineVault}   from "../../src/core/Vault.kerosine.bounded.sol";
import {VaultManager}           from "../../src/core/VaultManager.sol";
import {Dyad}                   from "../../src/core/Dyad.sol";
import {Kerosine}               from "../../src/staking/Kerosine.sol";
import {Staking}                from "../../src/staking/Staking.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract KerosineDeployBase is Script {
  function deploy(
    address      _owner, 
    ERC20        _stakingToken1,
    VaultManager _vaultManager,
    Dyad         _dyad

  ) public returns (
    Kerosine, 
    KerosineManager, 
    Staking, 
    UnboundedKerosineVault, 
    BoundedKerosineVault   
  ) {

    Kerosine        kerosine        = new Kerosine();
    KerosineManager kerosineManager = new KerosineManager();
    Staking staking                 = new Staking(_stakingToken1, kerosine);

    kerosineManager.transferOwnership(_owner);
    staking.        transferOwnership(_owner);

    // IMPORTANT: Vault needs to be licensed!
    UnboundedKerosineVault unboundedKerosineVault = new UnboundedKerosineVault(
      _vaultManager,
      kerosine, 
      _dyad,
      kerosineManager
    );

    // IMPORTANT: Vault needs to be licensed!
    BoundedKerosineVault boundedKerosineVault     = new BoundedKerosineVault(
      _vaultManager,
      kerosine, 
      _dyad,
      kerosineManager
    );

    return (
      kerosine,
      kerosineManager,
      staking,
      unboundedKerosineVault,
      boundedKerosineVault
    );
  }
}
