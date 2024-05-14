// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {Parameters}             from "../../src/params/Parameters.sol";
import {DNft}          from "../../src/core/DNft.sol";
import {VaultLicenser}          from "../../src/core/VaultLicenser.sol";
import {Licenser}               from "../../src/core/Licenser.sol";
import {Dyad}                   from "../../src/core/Dyad.sol";
import {VaultManagerV2}         from "../../src/core/VaultManagerV2.sol";
import {Vault}                  from "../../src/core/Vault.sol";
import {VaultWstEth}            from "../../src/core/Vault.wsteth.sol";
import {KerosineManager}        from "../../src/core/KerosineManager.sol";
import {IAggregatorV3}          from "../../src/interfaces/IAggregatorV3.sol";
import {Kerosine}               from "../../src/staking/Kerosine.sol";
import {UnboundedKerosineVault} from "../../src/core/Vault.kerosine.unbounded.sol";
import {KeroseneOracle}         from "../../src/core/KeroseneOracle.sol";
import {KerosineDenominator}    from "../../src/staking/KerosineDenominator.sol";
import {Staking}    from "../../src/staking/Staking.sol";

import {ERC20Mock} from "../../test/ERC20Mock.sol";
import {OracleMock} from "../../test/OracleMock.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC20}    from "@solmate/src/tokens/ERC20.sol";

import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {IUniswapV3Pool} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

// READ THIS FIRST PLEASE!
// !!!NOTE: We will never use this for prod!
// This is only for deploying the whole DYAD system to a non-forked testnet
// We are going to mock all Oracles!
contract DeployAll is Script, Parameters {
  // -------- STAKING CONTRACT UNI V2 --------
  uint ONE_MILLION     = 1_000_000;
  uint STAKING_REWARDS = ONE_MILLION * 10**18;

  function run() public {
    vm.startBroadcast();  // ----------------------

    DNft dNft                          = new DNft();
    Licenser      vaultManagerLicenser = new Licenser();
    Dyad          dyad                 = new Dyad(vaultManagerLicenser);
    VaultLicenser vaultLicenser        = new VaultLicenser();

    address proxy = Upgrades.deployUUPSProxy(
      "VaultManagerV2.sol",
      abi.encodeCall(
        VaultManagerV2.initialize,
        (
          dNft,
          dyad,
          vaultLicenser
        )
      )
    );

    VaultManagerV2 vaultManager = VaultManagerV2(proxy);
    vaultManager.transferOwnership(SEPOLIA_OWNER);

    vaultManagerLicenser.add(address(vaultManager));
    vaultManagerLicenser.transferOwnership(SEPOLIA_OWNER);

    ERC20Mock  weth       = new ERC20Mock("Wrapped Ether", "WETH");
    OracleMock wethOracle = new OracleMock(2000e8); // 2000 USD

    Vault ethVault = new Vault(
      vaultManager,
      weth,
      IAggregatorV3(address(wethOracle))
    );

    ERC20Mock  wstEth       = new ERC20Mock("Wrapped liquid staked Ether 2.0", "wstETH");
    OracleMock wstEthOracle = new OracleMock(2200e8); // 2000 USD

    VaultWstEth wstEthVault = new VaultWstEth(
      vaultManager, 
      wstEth, 
      IAggregatorV3(address(wstEthOracle))
    );

    Kerosine kerosene = new Kerosine();

    ERC20Mock uniV2Lp = new ERC20Mock("Uni V2 Lp Token", "UNI-V2-LP");
    Staking  staking  = new Staking(uniV2Lp, kerosene);

    kerosene.transfer(
      address(staking),
      STAKING_REWARDS
    );

    staking.setRewardsDuration(5 days);
    staking.notifyRewardAmount(STAKING_REWARDS);

    kerosene.transfer(
      SEPOLIA_OWNER,                           // multi-sig
      kerosene.totalSupply() - STAKING_REWARDS // the rest
    );

    staking.transferOwnership(SEPOLIA_OWNER);

    UnboundedKerosineVault unboundedKerosineVault = deployKerosene(
      address(ethVault),
      address(wstEthVault),
      vaultManager, 
      kerosene, 
      dyad
    );

    vaultLicenser.add(address(ethVault), false);
    vaultLicenser.add(address(wstEthVault),   false);
    vaultLicenser.add(address(unboundedKerosineVault), true);

    vaultLicenser.transferOwnership(SEPOLIA_OWNER);

    IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    address dyadPool = uniswapV3Factory.createPool(
      address(dyad),
      address(weth),
      500
    );

    IUniswapV3Pool pool = IUniswapV3Pool(dyadPool);
    pool.initialize(1e18);

    pool.mint(
      address(this),
      1, // tickLower
      200, // tickUpper
      1e18, // amount of DYAD
      ""
    );

    vm.stopBroadcast();  // ----------------------------
  }

  function deployKerosene(
    address ethVault,
    address wstEthVault,
    VaultManagerV2 vaultManager,
    Kerosine kerosene,
    Dyad dyad
  ) public returns (UnboundedKerosineVault) {
    KerosineManager kerosineManager = new KerosineManager();
    kerosineManager.add(ethVault);
    kerosineManager.add(wstEthVault);

    kerosineManager.transferOwnership(SEPOLIA_OWNER);

    KeroseneOracle keroseneOracle = new KeroseneOracle();

    UnboundedKerosineVault unboundedKerosineVault = new UnboundedKerosineVault(
      vaultManager,
      kerosene, 
      dyad,
      kerosineManager, 
      keroseneOracle
    );

    KerosineDenominator kerosineDenominator = new KerosineDenominator(
      kerosene
    );

    unboundedKerosineVault.setDenominator(kerosineDenominator);

    unboundedKerosineVault.transferOwnership(SEPOLIA_OWNER);

    return unboundedKerosineVault;
  }

  function onERC721Received(
      address,
      address,
      uint256,
      bytes calldata
  ) external pure returns (bytes4) {
      return 0x150b7a02;
  }
}
