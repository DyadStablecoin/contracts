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

  DNft                   dNft;                         
  Licenser               vaultManagerLicenser;
  Dyad                   dyad;                
  VaultLicenser          vaultLicenser;
  VaultManagerV2         vaultManager;
  Vault                  ethVault;
  VaultWstEth            wstEthVault;
  Kerosine               kerosene;
  UnboundedKerosineVault unboundedKerosineVault;

  function run() public {
    vm.startBroadcast();  // ----------------------

    deployBase();
    initVaultManager();
    initVaults();
    licenseVaults();
    initKeroseneAndStaking();
    initKeroseneManager();
    initStakingUniV3();

    vm.stopBroadcast();  // ----------------------------
  }

  function deployBase() public {
    dNft                 = new DNft();
    vaultManagerLicenser = new Licenser();
    dyad                 = new Dyad(vaultManagerLicenser);
    vaultLicenser        = new VaultLicenser();
  }

  function initVaultManager() public {
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

    vaultManager = VaultManagerV2(proxy);
    vaultManager.transferOwnership(SEPOLIA_OWNER);

    vaultManagerLicenser.add(address(vaultManager));
    vaultManagerLicenser.transferOwnership(SEPOLIA_OWNER);
  }

  function initVaults() public {
    ERC20Mock  weth       = new ERC20Mock("Wrapped Ether", "WETH");
    OracleMock wethOracle = new OracleMock(2000e8); // 2000 USD

    ethVault = new Vault(
      vaultManager,
      weth,
      IAggregatorV3(address(wethOracle))
    );

    ERC20Mock  wstEth       = new ERC20Mock("Wrapped liquid staked Ether 2.0", "wstETH");
    OracleMock wstEthOracle = new OracleMock(2200e8); // 2000 USD

    wstEthVault = new VaultWstEth(
      vaultManager, 
      wstEth, 
      IAggregatorV3(address(wstEthOracle))
    );
  }

  function initKeroseneAndStaking() public {
    kerosene = new Kerosine();

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
  }

  function licenseVaults() public {
    vaultLicenser.add(address(ethVault), false);
    vaultLicenser.add(address(wstEthVault),   false);
    vaultLicenser.add(address(unboundedKerosineVault), true);

    vaultLicenser.transferOwnership(SEPOLIA_OWNER);
  }

  function initStakingUniV3() public {
    IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    address dyadPool = uniswapV3Factory.createPool(
      address(dyad),
      address(SEPOLIA_WETH),
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
  }

  function initKeroseneManager() public {
    KerosineManager kerosineManager = new KerosineManager();
    kerosineManager.add(address(ethVault));
    kerosineManager.add(address(wstEthVault));

    kerosineManager.transferOwnership(SEPOLIA_OWNER);

    KeroseneOracle keroseneOracle = new KeroseneOracle();

    unboundedKerosineVault = new UnboundedKerosineVault(
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
