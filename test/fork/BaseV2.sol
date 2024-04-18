// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Parameters}          from "../../src/params/Parameters.sol";
import {Licenser}            from "../../src/core/Licenser.sol";
import {Modifiers}           from "../Modifiers.sol";
import {DeployV2, Contracts} from "../../script/deploy/Deploy.V2.s.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract BaseTestV2 is Modifiers, Parameters {
  Contracts contracts;
  ERC20 weth;

  uint DNFT_ID_1;

  function setUp() public {
    contracts = new DeployV2().run();
    weth      = ERC20(MAINNET_WETH);

    licenseVauleManager();
  }

  function licenseVauleManager() public {
    Licenser licenser = Licenser(MAINNET_VAULT_MANAGER_LICENSER);
    vm.prank(MAINNET_OWNER);
    licenser.add(address(contracts.vaultManager));
  }

  // --- RECEIVER ---
  receive() external payable {}

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure returns (bytes4) {
    return 0x150b7a02;
  }

}