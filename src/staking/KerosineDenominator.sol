// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Parameters} from "../params/Parameters.sol";
import {Kerosine} from "../staking/Kerosine.sol";

contract KerosineDenominator is Parameters {

  Kerosine public kerosine;

  constructor(
    Kerosine _kerosine
  ) {
    kerosine = _kerosine;
  }

  function denominator() external view returns (uint) {
    return kerosine.totalSupply() - kerosine.balanceOf(MAINNET_OWNER);
  } 
}
