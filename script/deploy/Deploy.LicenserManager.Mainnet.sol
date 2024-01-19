// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";

import {Parameters}      from "../../src/params/Parameters.sol";
import {LicenserManager} from "../../src/core/LicenserManager.sol";
import {Licenser}        from "../../src/core/LicenserManager.sol";

contract DeployLicenserManager is Script, Parameters {

  function run() public {
    new LicenserManager(
      Licenser(MAINNET_VAULT_LICENSER)
    );
  }
}
