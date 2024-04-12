// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {KerosineManager}        from "../../src/core/KerosineManager.sol";
import {UnboundedKerosineVault} from "../../src/core/Vault.kerosine.unbounded.sol";
import {BoundedKerosineVault}   from "../../src/core/Vault.kerosine.bounded.sol";
import {VaultManager}           from "../../src/core/VaultManager.sol";
import {Dyad}                   from "../../src/core/Dyad.sol";
import {Kerosine}               from "../../src/staking/Kerosine.sol";
import {KerosineDenominator}    from "../../src/staking/KerosineDenominator.sol";
import {Staking}                from "../../src/staking/Staking.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract KerosineDeployBase is Script {
  uint ONE_MILLION     = 1_000_000;
  uint STAKING_REWARDS = ONE_MILLION * 10**18;

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

    // weth
    kerosineManager.add(0xcF97cEc1907CcF9d4A0DC4F492A3448eFc744F6c);
    // wsteth
    kerosineManager.add(0x7aE80418051b2897729Cbdf388b07C5158C557A1);

    kerosine.transfer(
      address(staking),
      STAKING_REWARDS
    );

    staking.setRewardsDuration(5 days);
    staking.notifyRewardAmount(STAKING_REWARDS);

    kerosine.transfer(
      _owner,
      kerosine.totalSupply() - STAKING_REWARDS // the rest
    );

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
      kerosineManager
    );

    boundedKerosineVault.setUnboundedKerosineVault(unboundedKerosineVault);

    KerosineDenominator _kerosineDenominator = new KerosineDenominator(
      kerosine
    );

    unboundedKerosineVault.setDenominator(_kerosineDenominator);

    return (
      kerosine,
      kerosineManager,
      staking,
      unboundedKerosineVault,
      boundedKerosineVault
    );
  }
}
