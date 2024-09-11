// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IDyadXP.sol"; 
import "../interfaces/INonfungiblePositionManager.sol";
import {DNft} from "../core/DNft.sol";

contract UniswapV3Staking {
    IERC20 public rewardsToken;
    INonfungiblePositionManager public positionManager;
    IDyadXP public dyadXP; 
    DNft public dnft;

    struct StakeInfo {
        address staker;
        uint256 liquidity;
        uint256 lastRewardTime;
        uint256 tokenId;
        bool isStaked;
    }

    mapping(uint256 => StakeInfo) public stakes; 
    mapping(uint256 => bool) public usedNoteIds; 

    uint256 public rewardsRate; 

    event Staked(address indexed user, uint256 noteId, uint256 tokenId, uint256 liquidity);
    event Unstaked(address indexed user, uint256 noteId, uint256 tokenId);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(
        IERC20 _rewardsToken,
        INonfungiblePositionManager _positionManager,
        IDyadXP _dyadXP,
        uint256 _rewardsRate,
        DNft _dnft
    ) {
        rewardsToken = _rewardsToken;
        positionManager = _positionManager;
        dyadXP = _dyadXP; 
        rewardsRate = _rewardsRate;
        dnft = _dnft;
    }

    function stake(uint256 noteId, uint256 tokenId) external {
        require(dnft.ownerOf(noteId) == msg.sender, "You are not the Note owner");

        StakeInfo storage stakeInfo = stakes[noteId];
        require(!stakeInfo.isStaked, "Note already used for staking"); 

        (,,,,,,, uint128 liquidity,,,,) = positionManager.positions(tokenId);
        require(liquidity > 0, "No liquidity");

        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        stakes[noteId] = StakeInfo({
          staker: msg.sender,
          liquidity: liquidity,
          lastRewardTime: block.timestamp,
          tokenId: tokenId,
          isStaked: true
        });

        emit Staked(msg.sender, noteId, tokenId, liquidity);
    }

    function unstake(uint256 noteId) external {
        require(dnft.ownerOf(noteId) == msg.sender, "You are not the Note owner");
        StakeInfo storage stakeInfo = stakes[noteId];

        _claimRewards(noteId, stakeInfo);

        positionManager.safeTransferFrom(address(this), msg.sender, stakeInfo.tokenId);

        delete stakes[noteId];

        emit Unstaked(msg.sender, noteId, stakeInfo.tokenId);
    }

    function claimRewards(uint256 noteId) external {
        StakeInfo storage stakeInfo = stakes[noteId];
        require(dnft.ownerOf(noteId) == msg.sender, "You are not the Note owner");

        _claimRewards(noteId, stakeInfo);
    }

    function _claimRewards(uint256 noteId, StakeInfo storage stakeInfo) internal {
        uint256 rewards = _calculateRewards(noteId, stakeInfo);
        stakeInfo.lastRewardTime = block.timestamp;

        if (rewards > 0) {
            rewardsToken.transfer(stakeInfo.staker, rewards);
            emit RewardClaimed(stakeInfo.staker, rewards);
        }
    }

    function _calculateRewards(uint256 noteId, StakeInfo storage stakeInfo) internal view returns (uint256) {
        uint256 timeDiff = block.timestamp - stakeInfo.lastRewardTime;

        uint256 xp = dyadXP.balanceOfNote(noteId); 

        return timeDiff * rewardsRate * stakeInfo.liquidity * xp;
    }
}
