// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {DeployBase, Contracts} from "../script/deploy/DeployBase.s.sol";
import {Parameters} from "../src/params/Parameters.sol";
import {DNft} from "../src/core/DNft.sol";
import {Dyad} from "../src/core/Dyad.sol";
import {Licenser} from "../src/core/Licenser.sol";
import {VaultManager} from "../src/core/VaultManager.sol";
import {Vault} from "../src/core/Vault.sol";
import {Payments} from "../src/periphery/Payments.sol";
import {OracleMock} from "./OracleMock.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {IAggregatorV3} from "../src/interfaces/IAggregatorV3.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract BaseTest is Test, Parameters {
  DNft         dNft;
  Licenser     vaultManagerLicenser;
  Licenser     vaultLicenser;
  Dyad         dyad;
  VaultManager vaultManager;
  Payments     payments;

  // weth
  Vault        wethVault;
  ERC20Mock    weth;
  OracleMock   wethOracle;

  // dai
  Vault        daiVault;
  ERC20Mock    dai;
  OracleMock   daiOracle;

  function setUp() public {
    dNft       = new DNft();
    weth       = new ERC20Mock("WETH-TEST", "WETHT");
    wethOracle = new OracleMock(1000e8);

    Contracts memory contracts = new DeployBase().deploy(
      msg.sender,
      address(dNft),
      address(weth),
      address(wethOracle), 
      GOERLI_FEE,
      GOERLI_FEE_RECIPIENT
    );

    vaultManagerLicenser = contracts.vaultManagerLicenser;
    vaultLicenser        = contracts.vaultLicenser;
    dyad                 = contracts.dyad;
    vaultManager         = contracts.vaultManager;
    wethVault            = contracts.vault;
    payments             = contracts.payments;

    // create the DAI vault
    dai       = new ERC20Mock("DAI-TEST", "DAIT");
    daiOracle = new OracleMock(1e6);
    daiVault  = new Vault(
      vaultManager,
      ERC20(address(dai)),
      IAggregatorV3(address(daiOracle))
    );

    // add the DAI vault
    vm.prank(vaultLicenser.owner());
    vaultLicenser.add(address(daiVault));
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

