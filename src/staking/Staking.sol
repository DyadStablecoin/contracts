// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IStaking} from "../interfaces/IStaking.sol";

import {Owned}           from "@solmate/src/auth/Owned.sol";
import {ERC20}           from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

// from https://solidity-by-example.org/defi/staking-rewards/
contract Staking is IStaking, Owned(msg.sender) {
    using SafeTransferLib for ERC20;

    ERC20 public immutable stakingToken;
    ERC20 public immutable rewardsToken;

    // Duration of rewards to be paid out (in seconds)
    uint public duration; 
    // Timestamp of when the rewards finish
    uint public finishAt;
    // Minimum of last updated time and reward finish time
    uint public updatedAt;
    // Reward to be paid out per second
    uint public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint) public rewards;

    // Total staked
    uint public totalSupply;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    constructor(ERC20 _stakingToken, ERC20 _rewardToken) {
      stakingToken = _stakingToken;
      rewardsToken = _rewardToken;
    }

    modifier updateReward(address _account) {
      rewardPerTokenStored = rewardPerToken();
      updatedAt = lastTimeRewardApplicable();

      if (_account != address(0)) {
          rewards[_account] = earned(_account);
          userRewardPerTokenPaid[_account] = rewardPerTokenStored;
      }

      _;
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

    function stake(uint _amount) external updateReward(msg.sender) {
      require(_amount > 0, "amount = 0");
      stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
      balanceOf[msg.sender] += _amount;
      totalSupply += _amount;
      emit Staked(msg.sender, _amount);
    }

    function withdraw(uint _amount) external updateReward(msg.sender) {
      require(_amount > 0, "amount = 0");
      balanceOf[msg.sender] -= _amount;
      totalSupply -= _amount;
      stakingToken.safeTransfer(msg.sender, _amount);
      emit Withdrawn(msg.sender, _amount);
    }

    function earned(address _account) public view returns (uint) {
      return
          ((balanceOf[_account] *
              (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
          rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
      uint reward = rewards[msg.sender];
      if (reward > 0) {
          rewards[msg.sender] = 0;
          rewardsToken.safeTransfer(msg.sender, reward);
          emit RewardPaid(msg.sender, reward);
      }
    }

    function setRewardsDuration(uint _duration) external onlyOwner {
      require(finishAt < block.timestamp, "reward duration not finished");
      duration = _duration;
      emit RewardsDurationUpdated(_duration);
    }

    function notifyRewardAmount(
      uint _amount
    ) external onlyOwner updateReward(address(0)) {
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

    function _min(uint x, uint y) private pure returns (uint) {
      return x <= y ? x : y;
    }
}
