// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BoundedKerosineVault} from "../core/Vault.kerosine.bounded.sol";
import {ERC20}                from "@solmate/src/tokens/ERC20.sol";

contract KerosineDenominator {

  BoundedKerosineVault public boundedKerosineVault;
  ERC20                public asset;

  constructor(
    BoundedKerosineVault _boundedKerosineVault,
    ERC20                _asset
  ) {
    boundedKerosineVault = _boundedKerosineVault;
    asset                = _asset;
  }

  function denominator() external view returns (uint) {
    uint boundedKerosine = boundedKerosineVault.deposits();
    return asset.totalSupply() + 2*boundedKerosine;
  } 

}
