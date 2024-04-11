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
    // @dev: We subtract all the Kerosene in the multi-sig.
    //       We are aware that this is not a great solution. That is
    //       why we can switch out Denominator contracts.
    return kerosine.totalSupply() - kerosine.balanceOf(MAINNET_OWNER);
  } 
}
