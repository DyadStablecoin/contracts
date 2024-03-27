// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BoundedKerosineVault} from "../core/Vault.kerosine.bounded.sol";
import {ERC20}                from "@solmate/src/tokens/ERC20.sol";

contract KerosineDenominator {

  BoundedKerosineVault public boundedKerosineVault;

  constructor(
    BoundedKerosineVault _boundedKerosineVault
  ) {
    boundedKerosineVault = _boundedKerosineVault;
  }

  function denominator() external view returns (uint) {
    uint boundedKerosine = boundedKerosineVault.deposits();
    return boundedKerosineVault.asset().totalSupply() + 2*boundedKerosine;
  } 

}
