// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IStaking} from "../interfaces/IStaking.sol";

import {Owned} from "@solmate/src/auth/Owned.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {Ignition} from "./Ignition.sol";
import {Dyad} from "../core/Dyad.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

struct NoteDetails {
    uint128 balance;
    uint128 boost;
}

contract Staking is IStaking, Owned(msg.sender) {
    using SafeTransferLib for ERC20;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    uint256 public constant SCALING_FACTOR = 20000000 * 1e18;
    uint256 public constant BOOST_FACTOR = 4;
    uint256 public constant LP_FACTOR = 1;

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

    // @notice Total effective staked LP (includes tanh multipliers)
    // @dev this is what is used for reward rate calculations
    uint256 public totalSupply;
    // @notice User address => staked amount of LP tokens
    mapping(uint256 noteId => NoteDetails) public noteDetails;
    mapping(uint256 noteId => uint256 effectiveBalance) public effectiveBalanceOf;

    constructor(ERC20 _stakingToken, ERC20 _rewardToken, IERC721 _dNft, Ignition _ignition, Dyad _dyad, address _vaultManager) {
        stakingToken = _stakingToken;
        rewardsToken = _rewardToken;
        dNft = _dNft;
        ignition = _ignition;
        dyad = _dyad;
        vaultManager = _vaultManager;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
    }

    function stake(uint256 noteId, uint256 _amount) external {
        address noteholder = dNft.ownerOf(noteId);
        if (noteholder != msg.sender) revert NotOwnerOfNote();
        if (_amount == 0) revert InvalidAmount();

        // compute rewards based on the current balances before applying the stake
        _updateReward(noteId);

        // transfer LP tokens to this contract
        stakingToken.safeTransferFrom(noteholder, address(this), _amount);

        // update the note details
        uint256 oldEffectiveBalance = effectiveBalanceOf[noteId];
        noteDetails[noteId].balance += uint128(_amount);
        uint256 newEffectiveBalance = _effectiveBalance(noteId);
        effectiveBalanceOf[noteId] = newEffectiveBalance;

        // update the total supply
        totalSupply = totalSupply - oldEffectiveBalance + newEffectiveBalance;

        emit Staked(noteId, _amount);
    }

    function withdraw(uint256 noteId, uint256 _amount) external {
        address noteholder = dNft.ownerOf(noteId);
        if (noteholder != msg.sender) revert NotOwnerOfNote();
        if (_amount == 0) revert InvalidAmount();

        // compute rewards based on the current balances before applying the withdraw
        _updateReward(noteId);

        // update the note details
        uint256 oldEffectiveBalance = _effectiveBalance(noteId);
        noteDetails[noteId].balance -= uint128(_amount);
        uint256 newEffectiveBalance = _effectiveBalance(noteId);
        effectiveBalanceOf[noteId] = newEffectiveBalance;

        // update the total supply
        totalSupply = totalSupply - oldEffectiveBalance + newEffectiveBalance;

        // transfer LP tokens to the noteholder
        stakingToken.safeTransfer(noteholder, _amount);

        emit Withdrawn(noteId, _amount);
    }

    function updateBoost(uint256 noteId) external {
        if (msg.sender != address(ignition)) {
            if (msg.sender != vaultManager) {
                if (msg.sender != owner) {
                    revert NotAuthorized();
                }
            }
        }

        _updateBoost(noteId);
    }
    
    function batchUpdateBoost(uint256[] calldata noteIds) external onlyOwner {
        for (uint256 i = 0; i < noteIds.length; i++) {
            _updateBoost(noteIds[i]);
        }
    }

    function _updateBoost(uint256 noteId) internal {
        _updateReward(noteId);

        uint256 totalBoost = ignition.totalIgnited(noteId) + dyad.mintedDyad(noteId);

        uint256 oldEffectiveBalance = effectiveBalanceOf[noteId];
        noteDetails[noteId].boost = uint128(totalBoost);
        uint256 newEffectiveBalance = _effectiveBalance(noteId);
        effectiveBalanceOf[noteId] = newEffectiveBalance;
        totalSupply = totalSupply - oldEffectiveBalance + newEffectiveBalance;
    }

    function earned(uint256 noteId) public view returns (uint256) {
        return effectiveBalanceOf[noteId].mulWad(rewardPerToken() - userRewardPerTokenPaid[noteId]) + rewards[noteId];
    }

    function getReward(uint256 noteId) external {
        _updateReward(noteId);
        address noteholder = dNft.ownerOf(noteId);
        uint256 reward = rewards[noteId];
        if (reward > 0) {
            rewards[noteId] = 0;
            rewardsToken.safeTransfer(noteholder, reward);
            emit RewardPaid(noteId, reward);
        }
    }

    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
        emit RewardsDurationUpdated(_duration);
    }

    function notifyRewardAmount(uint256 _amount) external onlyOwner {
        _updateReward(type(uint256).max);
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint256 remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        require(rewardRate * duration <= rewardsToken.balanceOf(address(this)), "reward amount > balance");

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
        emit RewardAdded(_amount);
    }

    function _effectiveBalance(uint256 noteId) internal view returns (uint256) {
        NoteDetails memory details = noteDetails[noteId];
        uint256 tanhBoost = BOOST_FACTOR * _tanh(uint256(details.boost).divWad(SCALING_FACTOR));
        uint256 lpBoost = LP_FACTOR * _tanh(uint256(details.balance).divWad(SCALING_FACTOR));

        return tanhBoost + lpBoost;
    }

    function _updateReward(uint256 noteId) internal {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (noteId != type(uint256).max) {
            rewards[noteId] = earned(noteId);
            userRewardPerTokenPaid[noteId] = rewardPerTokenStored;
        }
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }

    /// @notice Computes the hyperbolic tangent of a number.
    /// @param x The number to compute the hyperbolic tangent of.
    /// @return The hyperbolic tangent of x.
    /// @dev tanh can be computed as (exp(x) - exp(-x)) / (exp(x) + exp(-x))
    ///      but we need to be careful with overflow: x must be less than 135 * WAD.
    function _tanh(uint256 x) internal pure returns (uint256) {
        int256 xInt = x.toInt256();

        if (xInt > 135305999368893231588) {
            xInt = 135305999368893231588;
        }
        int256 expX = xInt.expWad();
        int256 invExpX = (xInt * -1).expWad();

        return ((expX - invExpX) / (expX + invExpX)).toUint256();
    }
}
