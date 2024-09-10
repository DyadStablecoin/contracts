// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

contract UniswapV3Staking is Ownable {
    IERC20 public rewardsToken;
    INonfungiblePositionManager public positionManager;

    struct StakeInfo {
        address staker;
        uint256 rewardDebt;
        uint256 liquidity;
        uint256 lastRewardTime;
    }

    mapping(uint256 => StakeInfo) public stakes; // mapping from tokenId to StakeInfo
    mapping(address => uint256[]) public userStakes; // mapping from staker to tokenIds
    uint256 public rewardsRate; // rewards per second

    event Staked(address indexed user, uint256 tokenId, uint256 liquidity);
    event Unstaked(address indexed user, uint256 tokenId);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(IERC20 _rewardsToken, INonfungiblePositionManager _positionManager, uint256 _rewardsRate) {
        rewardsToken = _rewardsToken;
        positionManager = _positionManager;
        rewardsRate = _rewardsRate;
    }

    function stake(uint256 tokenId) external {
        require(positionManager.ownerOf(tokenId) == msg.sender, "You don't own this token");
        
        (, , , , , , , uint128 liquidity, , , , ) = positionManager.positions(tokenId);
        require(liquidity > 0, "Invalid liquidity");

        // Transfer NFT to the contract
        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        // Store stake information
        stakes[tokenId] = StakeInfo({
            staker: msg.sender,
            rewardDebt: 0,
            liquidity: liquidity,
            lastRewardTime: block.timestamp
        });
        userStakes[msg.sender].push(tokenId);

        emit Staked(msg.sender, tokenId, liquidity);
    }

    function unstake(uint256 tokenId) external {
        StakeInfo storage stakeInfo = stakes[tokenId];
        require(stakeInfo.staker == msg.sender, "Not your token");

        _claimRewards(tokenId);

        // Transfer the NFT back to the user
        positionManager.safeTransferFrom(address(this), msg.sender, tokenId);

        // Clean up storage
        delete stakes[tokenId];
        _removeUserStake(msg.sender, tokenId);

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
        return timeDiff * rewardsRate * stakeInfo.liquidity;
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

