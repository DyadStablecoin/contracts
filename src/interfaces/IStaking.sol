// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IStaking {
  event Staked                (address indexed user, uint amount);
  event Withdrawn             (address indexed user, uint amount);
  event RewardPaid            (address indexed user, uint reward);
  event RewardAdded           (uint reward);
  event RewardsDurationUpdated(uint newDuration);
}
