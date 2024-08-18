// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IDNft}         from "../interfaces/IDNft.sol";
import {IVault}        from "../interfaces/IVault.sol";
import {IAggregatorV3} from "../interfaces/IAggregatorV3.sol";
import {DNft}          from "../core/DNft.sol";

import {SafeCast}          from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeTransferLib}   from "@solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {ERC20}             from "@solmate/src/tokens/ERC20.sol";
import {Owned}             from "@solmate/src/auth/Owned.sol";

contract VaultWeETH is IVault, Owned {
  using SafeTransferLib   for ERC20;
  using SafeCast          for int;
  using FixedPointMathLib for uint;

  error ExceedsDepositCap();

  uint public constant STALE_DATA_TIMEOUT = 36 hours; 

  IVaultManager public immutable vaultManager;
  ERC20         public immutable asset;
  IAggregatorV3 public immutable oracle;
  IVault        public immutable wethVault;
  DNft          public immutable dNft;

  uint256 public depositCap;

  mapping(uint => uint) public id2asset;

  modifier onlyVaultManager() {
    if (msg.sender != address(vaultManager)) revert NotVaultManager();
    _;
  }

  constructor(
    address owner,
    IVaultManager _vaultManager,
    ERC20         _asset,
    IAggregatorV3 _oracle,
    IVault        _wethVault,
    DNft          _dNft
  ) Owned(owner) {
    vaultManager   = _vaultManager;
    asset          = _asset;
    oracle         = _oracle;
    wethVault      = _wethVault;
    dNft           = _dNft;
    depositCap     = type(uint256).max;
  }

  function deposit(uint id, uint amount) external onlyVaultManager {
      if (asset.balanceOf(address(this)) + amount > depositCap) {
          revert ExceedsDepositCap();
      }
      id2asset[id] += amount;
      emit Deposit(id, amount);
  }

  function withdraw(
    uint    id,
    address to,
    uint    amount
  ) 
    external 
      onlyVaultManager
  {
    id2asset[id] -= amount;
    asset.safeTransfer(to, amount); 
    emit Withdraw(id, to, amount);
  }

  function move(
    uint from,
    uint to,
    uint amount
  )
    external
      onlyVaultManager
  {
    id2asset[from] -= amount;
    id2asset[to]   += amount;
    emit Move(from, to, amount);
  }

  function getUsdValue(
    uint id
  )
    external
    view 
    returns (uint) {
      return id2asset[id] * assetPrice() 
              * 1e18 
              / 10**oracle.decimals() 
              / 10**asset.decimals();
  }


  function balanceOf(
      address account
  ) external view returns (uint256 assetBalance) {
      uint256 dnftBalance = dNft.balanceOf(account);
      for (uint256 i; i < dnftBalance; ++i) {
          uint256 id = dNft.tokenOfOwnerByIndex(account, i);
          assetBalance += id2asset[id];
      }
  }

  function setDepositCap(uint _depositCap) external onlyOwner {
       if (asset.balanceOf(address(this)) > _depositCap) {
          revert ExceedsDepositCap();
      }
      depositCap = _depositCap;
  }

  function assetPrice() 
    public 
    view 
    returns (uint) {
      (
        ,
        int256 answer,
        , 
        uint256 updatedAt, 
      ) = oracle.latestRoundData();
      if (block.timestamp > updatedAt + STALE_DATA_TIMEOUT) revert StaleData();
      return answer.toUint256().mulDivDown(wethVault.assetPrice(), 10 ** wethVault.oracle().decimals());
  }
}

