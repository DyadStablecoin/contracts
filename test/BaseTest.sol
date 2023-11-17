// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {DeployBase, Contracts} from "../script/deploy/DeployBase.s.sol";
import {Parameters} from "../src/Parameters.sol";
import {DNft} from "../src/core/DNft.sol";
import {Dyad} from "../src/core/Dyad.sol";
import {Licenser} from "../src/core/Licenser.sol";
import {VaultManager} from "../src/core/VaultManager.sol";
import {Vault} from "../src/core/Vault.sol";
import {OracleMock} from "./OracleMock.sol";
import {ERC20Mock} from "./ERC20Mock.sol";

contract BaseTest is Test, Parameters {
  DNft         dNft;
  Licenser     vaultManagerLicenser;
  Licenser     vaultLicenser;
  Dyad         dyad;
  VaultManager vaultManager;
  Vault        vault;
  ERC20Mock    weth;
  OracleMock   wethOracle;

  function setUp() public {
    dNft       = new DNft();
    weth       = new ERC20Mock("WETH-TEST", "WETHT");
    wethOracle = new OracleMock(1000e8);

    Contracts memory contracts = new DeployBase().deploy(
      msg.sender,
      address(dNft),
      address(weth),
      address(wethOracle)
    );

    vaultManagerLicenser = contracts.vaultManagerLicenser;
    vaultLicenser        = contracts.vaultLicenser;
    dyad                 = contracts.dyad;
    vaultManager         = contracts.vaultManager;
    vault                = contracts.vault;
  }

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

