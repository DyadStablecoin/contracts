// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Parameters} from "../src/params/Parameters.sol";
import {VaultWeETH} from "../src/core/Vault.weETH.sol";
import {VaultManager} from "../src/core/VaultManager.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {IAggregatorV3} from "../src/interfaces/IAggregatorV3.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {DNft} from "../src/core/DNft.sol";

contract VaultWeETHTest is Test, Parameters {
  VaultWeETH vault;

  function setUp() public {
    vault = new VaultWeETH(
      MAINNET_FEE_RECIPIENT,
      VaultManager (MAINNET_VAULT_MANAGER), 
      ERC20        (MAINNET_WEETH), 
      IAggregatorV3(MAINNET_CHAINLINK_WEETH),
      IVault(MAINNET_V2_WETH_VAULT),
      DNft(MAINNET_DNFT)
    );
  }

  function test_assetPrice() public {
    uint256 price = vault.assetPrice();
    console.log("price: %s", price);
  }
}
