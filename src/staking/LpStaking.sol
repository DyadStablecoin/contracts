// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV3PositionsNFT is IERC721 {
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

interface IXPContract {
    function getXP(address user) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract UniswapV3StakingWithXPBoost is Ownable {
    IUniswapV3PositionsNFT public uniswapNFT;
    IERC20 public rewardToken;
    IERC20 public xpContract; // Updated to IERC20
    uint256 public rewardRate; // Tokens rewarded per second per NFT staked

    struct StakeInfo {
        uint256 stakedAt;
        uint256 tokenId;
        address owner;
    }

    mapping(uint256 => StakeInfo) public stakes;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public lastUpdateTime;

    constructor(
        address _uniswapNFT,
        address _rewardToken,
        address _xpContract,
        uint256 _rewardRate
    ) {
        uniswapNFT = IUniswapV3PositionsNFT(_uniswapNFT);
        rewardToken = IERC20(_rewardToken);
        xpContract = IERC20(_xpContract); // Initialize as IERC20
        rewardRate = _rewardRate;
    }

    function stake(uint256 tokenId) external {
        require(uniswapNFT.ownerOf(tokenId) == msg.sender, "Not the NFT owner");
        uniswapNFT.transferFrom(msg.sender, address(this), tokenId);

        updateReward(msg.sender);

        stakes[tokenId] = StakeInfo({
            stakedAt: block.timestamp,
            tokenId: tokenId,
            owner: msg.sender
        });

        lastUpdateTime[msg.sender] = block.timestamp;
    }

    function unstake(uint256 tokenId) external {
        require(stakes[tokenId].owner == msg.sender, "Not the staker");

        updateReward(msg.sender);

        uniswapNFT.transferFrom(address(this), msg.sender, tokenId);
        delete stakes[tokenId];
    }

    function claimReward() external {
        updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        rewards[msg.sender] = 0;
        rewardToken.transfer(msg.sender, reward);
    }

    function updateReward(address account) internal {
        uint256 lastTime = lastUpdateTime[account];
        if (lastTime == 0) {
            lastUpdateTime[account] = block.timestamp;
            return;
        }

        uint256 timeDiff = block.timestamp - lastTime;
        uint256 baseReward = timeDiff * rewardRate;

        // Get user's XP balance and total XP supply from the XP contract
        uint256 userXP = xpContract.balanceOf(account);
        uint256 totalXP = xpContract.totalSupply();

        // Prevent division by zero
        if (totalXP == 0) {
            totalXP = 1;
        }

        // Calculate boost factor (scaled by 1e18 for precision)
        uint256 boostFactor = (userXP * 1e18) / totalXP;

        // Apply boost to the base reward
        uint256 boostedReward = baseReward + ((baseReward * boostFactor) / 1e18);

        rewards[account] += boostedReward;
        lastUpdateTime[account] = block.timestamp;
    }

    // Owner functions to set parameters
    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }

    function setXPContract(address _xpContract) external onlyOwner {
        xpContract = IERC20(_xpContract);
    }
}