// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IStaking} from "../interfaces/IStaking.sol";

import {Owned}           from "@solmate/src/auth/Owned.sol";
import {ERC20}           from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {Ignition} from "./Ignition.sol";
import {Dyad} from "../core/Dyad.sol";

// from https://solidity-by-example.org/defi/staking-rewards/
contract Staking is IStaking, Owned(msg.sender) {
    using SafeTransferLib for ERC20;

    ERC20 public immutable stakingToken;
    ERC20 public immutable rewardsToken;
    IERC721 public immutable dNft;
    Ignition public immutable ignition;
    Dyad public immutable dyad;
    address public immutable vaultManager;

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

    // Total staked
    uint256 public totalSupply;
    // User address => staked amount
    mapping(uint256 noteId => uint256 balance) public balanceOf;
    mapping(uint256 noteId => uint256 multiplier) public multipliers;

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

    function stake(uint256 noteId, uint _amount) external {
      address noteholder = dNft.ownerOf(noteId);
      require(noteholder == msg.sender, "not the owner");
      require(_amount > 0, "amount = 0");
      stakingToken.safeTransferFrom(noteholder, address(this), _amount);
      balanceOf[noteId] += _amount;
      totalSupply += _amount * multipliers[noteId];
      emit Staked(noteId, _amount);
    }

    function withdraw(uint256 noteId, uint _amount) external {
      address noteholder = dNft.ownerOf(noteId);
      require(noteholder == msg.sender, "not the owner");
      require(_amount > 0, "amount = 0");
      _updateReward(noteId);
      balanceOf[noteId] -= _amount;
      totalSupply -= _amount * multipliers[noteId];
      stakingToken.safeTransfer(noteholder, _amount);
      emit Withdrawn(noteId, _amount);
    }

    function updateBoost(uint256 noteId) external {
      if (msg.sender != address(ignition)) {
        if (msg.sender != address(vaultManager)) {
          revert("only ignition or vault manager");
        }
      }

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

      uint256 newMultiplier = totalIgnited + boost;
      totalSupply = totalSupply - (multipliers[noteId] * balance) + (newMultiplier * balance);
      multipliers[noteId] = newMultiplier;
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
}
