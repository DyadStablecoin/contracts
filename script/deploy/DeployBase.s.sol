// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import {DNft} from "../../src/core/DNft.sol";
import {Dyad} from "../../src/core/Dyad.sol";
import {Licenser} from "../../src/core/Licenser.sol";
import {VaultManager} from "../../src/core/VaultManager.sol";
import {Vault} from "../../src/core/Vault.sol";
import {IAggregatorV3} from "../../src/interfaces/AggregatorV3Interface.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract DeployBase is Script {

  function deploy(
    address _dNft,
    address _asset,
    address _oracle
  )
    public 
    payable 
    returns (
      address, 
      address, 
      address, 
      address, 
      address
    ) {
      DNft dNft = DNft(_dNft);

      vm.startBroadcast();  // ------------------------------------------

      Licenser vaultManagerLicenser = new Licenser();
      Licenser vaultLicenser        = new Licenser();

      Dyad dyad                     = new Dyad(
        vaultManagerLicenser
      );

      VaultManager vaultManager     = new VaultManager(
        dNft,
        dyad,
        vaultLicenser
      );

      Vault vault                   = new Vault(
        vaultManager,
        ERC20(_asset),
        IAggregatorV3(_oracle)
      );

      vm.stopBroadcast();  // ------------------------------------------

      return (
        address(vaultManagerLicenser), 
        address(vaultLicenser),
        address(dyad),
        address(vaultManager),
        address(vault)
      );
  }
}
