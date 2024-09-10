// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDyadXP.sol"; 
import "../interfaces/IDNft.sol"; 

interface INonfungiblePositionManager {
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

contract UniswapV3Staking is Ownable(0xDeD796De6a14E255487191963dEe436c45995813) {
    IERC20 public rewardsToken;
    INonfungiblePositionManager public positionManager;
    IDyadXP public dyadXP; 
    IDNft public dnft;

    struct StakeInfo {
        address staker;
        uint256 rewardDebt;
        uint256 liquidity;
        uint256 lastRewardTime;
        uint256 noteId;
    }

    mapping(uint256 => StakeInfo) public stakes; 
    mapping(address => uint256[]) public userStakes; 
    uint256 public rewardsRate; 

    event Staked(address indexed user, uint256 tokenId, uint256 liquidity);
    event Unstaked(address indexed user, uint256 tokenId);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(IERC20 _rewardsToken, INonfungiblePositionManager _positionManager, IDyadXP _dyadXP, uint256 _rewardsRate, IDNft _dnft) {
        rewardsToken = _rewardsToken;
        positionManager = _positionManager;
        dyadXP = _dyadXP; 
        rewardsRate = _rewardsRate;
        dnft = _dnft;
    }

    function stake(uint256 tokenId, uint256 noteId) external {
        require(positionManager.ownerOf(tokenId) == msg.sender, "You don't own this token");

        (,,,,,,, uint128 liquidity,,,,) = positionManager.positions(tokenId);
        require(liquidity > 0, "Invalid liquidity");

        // Transfer NFT to the contract
        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        stakes[tokenId] =
            StakeInfo({staker: msg.sender, rewardDebt: 0, liquidity: liquidity, lastRewardTime: block.timestamp, noteId: noteId});
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
