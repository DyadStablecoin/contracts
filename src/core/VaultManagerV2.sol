// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {VaultManager} from "./VaultManager.sol";
import {DNft}         from "../../src/core/DNft.sol";
import {Dyad}         from "../../src/core/Dyad.sol";
import {Licenser}     from "../../src/core/Licenser.sol";

contract VaultManagerV2 is VaultManager {

  // id => (block number => deposited)
  mapping (uint => mapping (uint => bool)) public deposited;

  constructor(
    DNft     _dNft,
    Dyad     _dyad,
    Licenser _licenser
  ) VaultManager(_dNft, _dyad, _licenser) {}

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
    deposited[id][block.number] = true;
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
    if (!deposited[id][block.number]) revert DepositedInThisBlock();
    super.withdraw(id, vault, amount, to);
  }
}
