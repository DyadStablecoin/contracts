// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {VaultManager} from "./VaultManager.sol";
import {DNft}         from "../../src/core/DNft.sol";
import {Dyad}         from "../../src/core/Dyad.sol";
import {Licenser}     from "../../src/core/Licenser.sol";

// @dev: Same as VaultManager but with flash loan protection.
contract VaultManagerV2 is VaultManager {
  
  error DepositedInSameBlock();

  mapping (uint => uint) public idToBlockOfLastDeposit;

  constructor(
    DNft     dNft,
    Dyad     dyad,
    Licenser licenser
  ) VaultManager(dNft, dyad, licenser) {}

  /// @inheritdoc VaultManager
  function deposit(
    uint    id,
    address vault,
    uint    amount
  ) 
    override
    public 
      isValidDNft(id) 
  {
    idToBlockOfLastDeposit[id] = block.number;
    super.deposit(id, vault, amount);
  }

  /// @inheritdoc VaultManager
  function withdraw(
    uint    id,
    address vault,
    uint    amount,
    address to
  ) 
    override
    public 
      isDNftOwner(id)
  {
    if (idToBlockOfLastDeposit[id] == block.number) revert DepositedInSameBlock();
    super.withdraw(id, vault, amount, to);
  }
}
