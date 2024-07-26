// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Dyad}  from "../core/Dyad.sol";
import {Vault} from "../core/Vault.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";

contract Lending {
  using FixedPointMathLib for uint;

  uint public constant k = 0.1e18;

  Dyad  public dyad;
  Vault public ethVault;

  uint  public totalDyadLent;
  uint  public totalDyadBorrowed;

  constructor(
    Dyad  _dyad,
    Vault _ethVault
  ) {
    dyad     = _dyad;
    ethVault = _ethVault;
  }

  function getInterestRate(uint id) 
    public 
    view 
    returns (uint) 
  {
    uint eth = ethVault.id2asset(id).mulWadDown(ethVault.assetPrice());
    uint a   = eth.mulWadDown(dyad.balanceOf(address(ethVault)));
    uint b   = (totalDyadBorrowed**2).mulWadDown(a);
    return k.mulWadDown(a);
  }
}
