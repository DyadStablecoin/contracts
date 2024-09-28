// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IStaking} from "../interfaces/IStaking.sol";

import {Owned}           from "@solmate/src/auth/Owned.sol";
import {ERC20}           from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {Ignition} from "./Ignition.sol";
import {Dyad} from "../core/Dyad.sol";

contract Staking is IStaking, Owned(msg.sender) {
    using SafeTransferLib for ERC20;

    ERC20 public immutable stakingToken;
    ERC20 public immutable rewardsToken;
    IERC721 public immutable dNft;
    Ignition public immutable ignition;
    Dyad public immutable dyad;

    address public vaultManager;

    // Duration of rewards to be paid out (in seconds)
    uint256 public duration; 
    // Timestamp of when the rewards finish
    uint256 public finishAt;
    // Minimum of last updated time and reward finish time
    uint256 public updatedAt;
    // Reward to be paid out per second
    uint256 public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint256 public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(uint256 noteId => uint256 rewardPerTokenPaid) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(uint256 noteId => uint256 rewards) public rewards;

    // @notice Total effective staked LP (includes tanh multipliers)
    // @dev this is what is used for reward rate calculations
    uint256 public totalSupply;
    // @notice User address => staked amount of LP tokens
    mapping(uint256 noteId => uint256 balance) public balanceOf;
    // @notice User address => multiplier for kero + minted dyad
    mapping(uint256 noteId => uint256 multiplier) public ignitionBoost;

    constructor(ERC20 _stakingToken, ERC20 _rewardToken, IERC721 _dNft, Ignition _ignition, Dyad _dyad) {
      stakingToken = _stakingToken;
      rewardsToken = _rewardToken;
      dNft = _dNft;
      ignition = _ignition;
      dyad = _dyad;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
      return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint) {
      if (totalSupply == 0) {
          return rewardPerTokenStored;
      }

      return
          rewardPerTokenStored +
          (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
          totalSupply;
    }

    function setVaultManager(address _vaultManager) public onlyOwner {
      vaultManager = _vaultManager;
    }

    function stake(uint256 noteId, uint _amount) external {
      address noteholder = dNft.ownerOf(noteId);
      require(noteholder == msg.sender, "not the owner");
      require(_amount > 0, "amount = 0");
      _updateReward(noteId);
      stakingToken.safeTransferFrom(noteholder, address(this), _amount);
      uint256 oldEffectiveBalance = _effectiveBalance(noteId);
      balanceOf[noteId] += _amount;
      totalSupply = totalSupply - oldEffectiveBalance + _effectiveBalance(noteId);
      emit Staked(noteId, _amount);
    }

    function withdraw(uint256 noteId, uint _amount) external {
      address noteholder = dNft.ownerOf(noteId);
      require(noteholder == msg.sender, "not the owner");
      require(_amount > 0, "amount = 0");
      _updateReward(noteId);
      uint256 oldEffectiveBalance = _effectiveBalance(noteId);
      balanceOf[noteId] -= _amount;
      totalSupply = totalSupply - oldEffectiveBalance + _effectiveBalance(noteId);
      stakingToken.safeTransfer(noteholder, _amount);
      emit Withdrawn(noteId, _amount);
    }

    function updateBoost(uint256 noteId) external {
      require(
          msg.sender == address(ignition) || msg.sender == address(vaultManager),
          "only ignition or vault manager"
      );

      uint256 balance = balanceOf[noteId];

      if (balance > 0) {
        _updateReward(noteId);
      }

      uint256 totalIgnited = ignition.totalIgnited(noteId);
      uint256 dyadMinted = dyad.mintedDyad(noteId);

      uint256 boost;
      if (totalIgnited > 0) {
        if (dyadMinted > 0) {
          boost = totalIgnited * (dyadMinted / (dyadMinted / totalIgnited));
        }
      }

      uint256 oldEffectiveBalance = _effectiveBalance(noteId);
      multipliers[noteId] = totalIgnited + boost;
      totalSupply = totalSupply - oldEffectiveBalance + _effectiveBalance(noteId);
    }

    function earned(uint256 noteId) public view returns (uint) {
      return
          ((_effectiveBalance(noteId) *
              (rewardPerToken() - userRewardPerTokenPaid[noteId])) / 1e18) +
          rewards[noteId];
    }

    function getReward(uint256 noteId) external {
      _updateReward(noteId);
      address noteholder = dNft.ownerOf(noteId);
      uint reward = rewards[noteId];
      if (reward > 0) {
          rewards[noteId] = 0;
          rewardsToken.safeTransfer(noteholder, reward);
          emit RewardPaid(noteId, reward);
      }
    }

    function setRewardsDuration(uint _duration) external onlyOwner {
      require(finishAt < block.timestamp, "reward duration not finished");
      duration = _duration;
      emit RewardsDurationUpdated(_duration);
    }

    function notifyRewardAmount(
      uint _amount
    ) external onlyOwner {
      _updateReward(type(uint256).max);
      if (block.timestamp >= finishAt) {
          rewardRate = _amount / duration;
      } else {
          uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
          rewardRate = (_amount + remainingRewards) / duration;
      }

      require(rewardRate > 0, "reward rate = 0");
      require(
          rewardRate * duration <= rewardsToken.balanceOf(address(this)),
          "reward amount > balance"
      );

      finishAt = block.timestamp + duration;
      updatedAt = block.timestamp;
      emit RewardAdded(_amount);
    }

    function _effectiveBalance(uint256 noteId) internal view returns (uint256) {
      
//      uint256 tanhBoost = _tanh(multipliers[noteId].divWad(MAX_BOOST_FACTOR));
//      uint256 lpBoost = _tanh(balanceOf[noteId].divWad(MAX_LP_FACTOR));
      return balanceOf[noteId] * multipliers[noteId];
    }

    function _updateReward(uint256 noteId) internal {
      rewardPerTokenStored = rewardPerToken();
      updatedAt = lastTimeRewardApplicable();

      if (noteId != type(uint256).max) {
          rewards[noteId] = earned(noteId);
          userRewardPerTokenPaid[noteId] = rewardPerTokenStored;
      }
    }

    function _min(uint x, uint y) private pure returns (uint) {
      return x <= y ? x : y;
    }

    /// @notice Computes the hyperbolic tangent of a number.
    /// @param x The number to compute the hyperbolic tangent of.
    /// @return The hyperbolic tangent of x.
    /// @dev tanh can be computed as (exp(x) - exp(-x)) / (exp(x) + exp(-x))
    ///      but we need to be careful with overflow: x must be less than 135 * WAD.
    function _tanh(uint256 x) internal pure returns (uint256) {
      int256 xInt = x.toInt256();
      expX = xInt.expWad();
      invExpX = (xInt * -1).expWad();

      return ((expX - invExpX) / (expX + invExpX)).toUint256();
    }
}
