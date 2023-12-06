// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {VaultManager} from "../core/VaultManager.sol";
import {Vault}        from "../core/Vault.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {SafeTransferLib}   from "@solmate/src/utils/SafeTransferLib.sol";
import {Owned}             from "@solmate/src/auth/Owned.sol";
import {ERC20}             from "@solmate/src/tokens/ERC20.sol";

contract Payments is Owned(msg.sender) {
  using FixedPointMathLib for uint;
  using SafeTransferLib   for ERC20;

  VaultManager public immutable vaultManager;

  uint    public fee;
  address public feeRecipient;

  constructor(VaultManager _vaultManager) { 
    vaultManager = _vaultManager;
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

  function deposit(
    uint    id,
    address vault,
    uint    amount
  ) 
    external 
  {
    ERC20 asset = Vault(vault).asset();
    asset.safeTransferFrom(msg.sender, address(this), amount);

    uint feeAmount = amount.mulWadDown(fee);
    asset.safeTransfer(feeRecipient, feeAmount);

    uint netAmount = amount - feeAmount;
    asset.approve(address(vaultManager), netAmount);
    vaultManager.deposit(id, vault, netAmount);
  }
}
