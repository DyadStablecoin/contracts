// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VaultManager} from "../core/VaultManager.sol";
import {Vault}        from "../core/Vault.sol";
import {IWETH}        from "../interfaces/IWETH.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {SafeTransferLib}   from "@solmate/src/utils/SafeTransferLib.sol";
import {Owned}             from "@solmate/src/auth/Owned.sol";
import {ERC20}             from "@solmate/src/tokens/ERC20.sol";

contract Payments is Owned(msg.sender) {
  using FixedPointMathLib for uint;
  using SafeTransferLib   for ERC20;
  using SafeTransferLib   for address;

  VaultManager public immutable vaultManager;
  IWETH        public immutable weth;

  uint    public fee;
  address public feeRecipient;

  constructor(
    VaultManager _vaultManager,
    IWETH        _weth
  ) { 
    vaultManager = _vaultManager;
    weth         = _weth;
  }

  function setFee(
    uint _fee
  ) 
    external 
    onlyOwner 
  {
    fee = _fee;
  }

  function setFeeRecipient(
    address _feeRecipient
  ) 
    external 
    onlyOwner 
  {
    feeRecipient = _feeRecipient;
  }

  // Calls the Vault Manager `deposit` function, but takes a fee.
  function depositWithFee(
    uint    id,
    address vault,
    uint    amount
  ) 
    external 
  {
    ERC20 asset = Vault(vault).asset();
    asset.safeTransferFrom(msg.sender, address(this), amount);

    _deposit(id, vault, amount);
  }

  function depositETHWithFee(
    uint    id,
    address vault
  ) 
    external 
    payable
  {
    weth.deposit{value: msg.value}();
    _deposit(id, vault, msg.value);
  }

  function _deposit(
    uint    id,
    address vault,
    uint    amount
  ) 
    internal 
  {
    ERC20 asset = Vault(vault).asset();

    uint feeAmount = amount.mulWadDown(fee);
    asset.safeTransfer(feeRecipient, feeAmount);

    uint netAmount = amount - feeAmount;
    asset.approve(address(vaultManager), netAmount);
    vaultManager.deposit(id, vault, netAmount);
  }

  function drain(address to)
    external
      onlyOwner
  {
    to.safeTransferETH(address(this).balance);
  }
}
