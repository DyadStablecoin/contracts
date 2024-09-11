// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IDyadXP.sol"; 
import "../interfaces/INonfungiblePositionManager.sol";
import {DNft} from "../core/DNft.sol";

contract UniswapV3Staking {
    uint256 public constant MAX_STAKES = 10;

    IERC20 public rewardsToken;
    INonfungiblePositionManager public positionManager;
    IDyadXP public dyadXP; 
    DNft public dnft;

    struct StakeInfo {
        address staker;
        uint256 liquidity;
        uint256 lastRewardTime;
        uint256 noteId;
    }

    mapping(uint256 => StakeInfo) public stakes; 
    mapping(address => uint256[]) public userStakes; 
    mapping(uint256 => bool) public usedNoteIds; 

    uint256 public rewardsRate; 

    event Staked(address indexed user, uint256 tokenId, uint256 liquidity);
    event Unstaked(address indexed user, uint256 tokenId);
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

    function stake(uint256 tokenId, uint256 noteId) external {
        require(positionManager.ownerOf(tokenId) == msg.sender, "You are not the LP owner");
        require(dnft.ownerOf(noteId) == msg.sender, "You are not the Note owner");
        require(userStakes[msg.sender].length < MAX_STAKES, "Maximum of stakes reached");
        require(!usedNoteIds[noteId], "Note already used for staking"); 

        (,,,,,,, uint128 liquidity,,,,) = positionManager.positions(tokenId);
        require(liquidity > 0, "No liquidity");

        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        stakes[tokenId] = StakeInfo({
          staker: msg.sender,
          liquidity: liquidity,
          lastRewardTime: block.timestamp,
          noteId: noteId
        });
        userStakes[msg.sender].push(tokenId);
        usedNoteIds[noteId] = true;

        emit Staked(msg.sender, tokenId, liquidity);
    }

    function unstake(uint256 tokenId) external {
        StakeInfo storage stakeInfo = stakes[tokenId];
        require(stakeInfo.staker == msg.sender, "Not your token");
        require(dnft.ownerOf(stakeInfo.noteId) == msg.sender, "You are not the Note owner");

        _claimRewards(tokenId);

        positionManager.safeTransferFrom(address(this), msg.sender, tokenId);

        // Clean up storage
        delete stakes[tokenId];
        _removeUserStake(msg.sender, tokenId);
        usedNoteIds[stakeInfo.noteId] = false;

        emit Unstaked(msg.sender, tokenId);
    }

    function claimRewards(uint256 tokenId) external {
        StakeInfo storage stakeInfo = stakes[tokenId];
        require(stakeInfo.staker == msg.sender, "Not your token");

        _claimRewards(tokenId);
    }

    function _claimRewards(uint256 tokenId) internal {
        StakeInfo storage stakeInfo = stakes[tokenId];
        uint256 rewards = _calculateRewards(tokenId);
        stakeInfo.lastRewardTime = block.timestamp;

        if (rewards > 0) {
            rewardsToken.transfer(stakeInfo.staker, rewards);
            emit RewardClaimed(stakeInfo.staker, rewards);
        }
    }

    function _calculateRewards(uint256 tokenId) internal view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[tokenId];
        uint256 timeDiff = block.timestamp - stakeInfo.lastRewardTime;

        uint256 xp = dyadXP.balanceOfNote(stakeInfo.noteId); 

        return timeDiff * rewardsRate * stakeInfo.liquidity * xp;
    }

    function _removeUserStake(address user, uint256 tokenId) internal {
        uint256[] storage stakesArray = userStakes[user];
        for (uint256 i = 0; i < stakesArray.length; i++) {
            if (stakesArray[i] == tokenId) {
                stakesArray[i] = stakesArray[stakesArray.length - 1];
                stakesArray.pop();
                break;
            }
        }
    }
}
