// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Parameters} from "../src/params/Parameters.sol";
import {VaultWstEth} from "../src/core/Vault.wsteth.sol";
import {VaultManager} from "../src/core/VaultManager.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {IAggregatorV3} from "../src/interfaces/IAggregatorV3.sol";
import {IWstETH} from "../src/interfaces/IWstETH.sol";

contract VaultWstEthTest is Test, Parameters {
  VaultWstEth vault;

  function setUp() public {
    vault = new VaultWstEth(
      VaultManager (MAINNET_VAULT_MANAGER), 
      ERC20        (MAINNET_WSTETH), 
      IAggregatorV3(MAINNET_CHAINLINK_STETH)
    );
  }

  function test_assetPrice() public {
    uint256 price = vault.assetPrice();
    console.log("price: %s", price);
  }
}
