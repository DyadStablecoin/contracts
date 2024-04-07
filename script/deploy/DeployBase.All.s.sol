//// SPDX-License-Identifier: MIT
//pragma solidity =0.8.17;

//import "forge-std/Script.sol";
//import {DNft}          from "../../src/core/DNft.sol";
//import {Dyad}          from "../../src/core/Dyad.sol";
//import {Licenser}      from "../../src/core/Licenser.sol";
//import {VaultManager}  from "../../src/core/VaultManager.sol";
//import {Vault}         from "../../src/core/Vault.sol";
//import {Payments}      from "../../src/periphery/Payments.sol";
//import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";
//import {IWETH}         from "../../src/interfaces/IWETH.sol";
//import {KerosineManager}        from "../../src/core/KerosineManager.sol";
//import {UnboundedKerosineVault} from "../../src/core/Vault.kerosine.unbounded.sol";
//import {BoundedKerosineVault}   from "../../src/core/Vault.kerosine.bounded.sol";
//import {Kerosine}               from "../../src/staking/Kerosine.sol";
//import {Staking}                from "../../src/staking/Staking.sol";


//import {ERC20} from "@solmate/src/tokens/ERC20.sol";

//// only used for stack too deep issues
//struct Contracts {
//  Licenser     vaultManagerLicenser;
//  Licenser     vaultLicenser;
//  Dyad         dyad;
//  VaultManager vaultManager;
//  Vault        vault;
//  Payments     payments;
//}

//contract DeployBase is Script {

//  function deploy(
//    address _owner, 
//    address _asset,
//    address _oracle, 
//    uint    _fee,
//    address _feeRecipient
//  )
//    public 
//    payable 
//    returns (
//      Contracts memory
//    ) {
//      vm.startBroadcast();  // ----------------------

//      DNft dNft = new DNft();

//      Licenser vaultManagerLicenser = new Licenser();
//      Licenser vaultLicenser        = new Licenser();

//      Dyad dyad                     = new Dyad(
//        vaultManagerLicenser
//      );

//      VaultManager vaultManager     = new VaultManager(
//        dNft,
//        dyad,
//        vaultLicenser
//      );

//      Vault vault                   = new Vault(
//        vaultManager,
//        ERC20(_asset),
//        IAggregatorV3(_oracle)
//      );

//      Payments payments             = new Payments(
//        vaultManager,
//        IWETH(_asset)
//      );

//      //
//      payments.setFee(_fee);
//      payments.setFeeRecipient(_feeRecipient);

//      // 
//      vaultManagerLicenser.add(address(vaultManager));
//      vaultLicenser       .add(address(vault));

//      //
//      vaultManagerLicenser.transferOwnership(_owner);
//      vaultLicenser       .transferOwnership(_owner);
//      payments            .transferOwnership(_owner);

//      // new VaultWstEth(
//      //   VaultManager (address(vaultManager)), 
//      //   ERC20        (SEPOLIA_WSTETH), 
//      //   IAggregatorV3(SEPOLIA_CHAINLINK_STETH)
//      // );

//      Kerosine        kerosine        = new Kerosine();
//      KerosineManager kerosineManager = new KerosineManager();
//      Staking staking                 = new Staking(
//        ERC20(0x1F79BeD01b0fF658dbb47b4005F1B571Ef06D0FD),
//        kerosine
//      );

//      uint STAKING_REWARDS = 1_000_000 * 10**18;

//      kerosine.transfer(
//        address(staking),
//        STAKING_REWARDS
//      );

//      staking.setRewardsDuration(5 days);
//      staking.notifyRewardAmount(STAKING_REWARDS);

//      kerosine.transfer(
//        _owner,
//        kerosine.totalSupply() - STAKING_REWARDS // the rest
//      );

//      kerosineManager.transferOwnership(_owner);
//      staking.        transferOwnership(_owner);

//      // IMPORTANT: Vault needs to be licensed!
//      UnboundedKerosineVault unboundedKerosineVault = new UnboundedKerosineVault(
//        vaultManager,
//        kerosine, 
//        dyad,
//        kerosineManager
//      );

//      // IMPORTANT: Vault needs to be licensed!
//      BoundedKerosineVault boundedKerosineVault     = new BoundedKerosineVault(
//        vaultManager,
//        kerosine, 
//        dyad,
//        kerosineManager
//      );

//      boundedKerosineVault.setUnboundedKerosineVault(unboundedKerosineVault);

//      vm.stopBroadcast();  // ----------------------------

//      return Contracts(
//        vaultManagerLicenser,
//        vaultLicenser,
//        dyad,
//        vaultManager,
//        vault, 
//        payments
//      );
//  }
//}
