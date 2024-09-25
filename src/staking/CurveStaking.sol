// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDyadXP.sol";
import {DNft} from "../core/DNft.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract CurveLPStaking is UUPSUpgradeable, OwnableUpgradeable {
    IERC20 public rewardsToken;
    IERC20 public lpToken; // Curve LP Token
    IDyadXP public dyadXP;
    DNft public dnft;
    uint256 public rewardsRate;
    address public rewardsTokenHolder;

    struct StakeInfo {
        uint256 amount; // amount of LP tokens staked
        uint256 lastRewardTime;
        bool isStaked;
    }

    mapping(uint256 => StakeInfo) public stakes;

    event Staked(address indexed user, uint256 noteId, uint256 amount);
    event Unstaked(address indexed user, uint256 noteId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        IERC20 _rewardsToken,
        IERC20 _lpToken,
        IDyadXP _dyadXP,
        DNft _dnft,
        uint256 _rewardsRate,
        address _rewardsTokenHolder
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(_owner);

        rewardsToken = _rewardsToken;
        lpToken = _lpToken;
        dyadXP = _dyadXP;
        dnft = _dnft;
        rewardsRate = _rewardsRate;
        rewardsTokenHolder = _rewardsTokenHolder;
    }

    function stake(uint256 noteId, uint256 amount) external {
        require(dnft.ownerOf(noteId) == msg.sender, "You are not the Note owner");

        StakeInfo storage stakeInfo = stakes[noteId];
        require(!stakeInfo.isStaked, "Note already used for staking");
        require(amount > 0, "Cannot stake zero amount");

        // Transfer LP tokens from the user to the contract
        lpToken.transferFrom(msg.sender, address(this), amount);

        stakes[noteId] = StakeInfo({
            amount: amount,
            lastRewardTime: block.timestamp,
            isStaked: true
        });

        emit Staked(msg.sender, noteId, amount);
    }

    function unstake(uint256 noteId, address recipient) external {
        StakeInfo storage stakeInfo = stakes[noteId];
        require(dnft.ownerOf(noteId) == msg.sender, "You are not the Note owner");
        require(stakeInfo.isStaked, "Note not staked");

        _claimRewards(noteId, stakeInfo, recipient);

        uint256 amount = stakeInfo.amount;

        delete stakes[noteId];

        // Transfer LP tokens back to the user
        lpToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, noteId, amount);
    }

    function claimRewards(uint256 noteId, address recipient) external {
        StakeInfo storage stakeInfo = stakes[noteId];

        _claimRewards(noteId, stakeInfo, recipient);
    }

    function _claimRewards(uint256 noteId, StakeInfo storage stakeInfo, address recipient) internal {
        require(dnft.ownerOf(noteId) == msg.sender, "You are not the Note owner");
        require(stakeInfo.isStaked, "Note not staked");
        uint256 rewards = _calculateRewards(noteId, stakeInfo);

        if (rewards > 0) {
            stakeInfo.lastRewardTime = block.timestamp;
            rewardsToken.transferFrom(rewardsTokenHolder, recipient, rewards);
            emit RewardClaimed(recipient, rewards);
        }
    }

    function _calculateRewards(uint256 noteId, StakeInfo storage stakeInfo) internal view returns (uint256) {
        uint256 timeDiff = block.timestamp - stakeInfo.lastRewardTime;

        uint256 xp = dyadXP.balanceOfNote(noteId);

        uint256 amount = stakeInfo.amount;
        return timeDiff * rewardsRate * amount * xp / 1e36;
    }

    function currentRewards(uint256 noteId) external view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[noteId];
        return _calculateRewards(noteId, stakeInfo);
    }

    function setRewardsRate(uint256 _rewardsRate) external onlyOwner {
        rewardsRate = _rewardsRate;
    }

    function setRewardsTokenHolder(address _rewardsTokenHolder) external onlyOwner {
        rewardsTokenHolder = _rewardsTokenHolder;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

