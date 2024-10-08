// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDyadXP.sol"; 
import "../interfaces/INonfungiblePositionManager.sol";
import {DNft} from "../core/DNft.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable}    from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract UniswapV3Staking is UUPSUpgradeable, OwnableUpgradeable { 
    IERC20 public rewardsToken;
    INonfungiblePositionManager public positionManager;
    IDyadXP public dyadXP; 
    DNft public dnft;
    uint256 public rewardsRate; 
    address public rewardsTokenHolder;
    address public token0;
    address public token1;
    uint24 public poolFee;

    struct StakeInfo {
        uint256 liquidity;
        uint256 lastRewardTime;
        uint256 tokenId;
        bool isStaked;
    }

    mapping(uint256 => StakeInfo) public stakes; 

    event Staked(address indexed user, uint256 noteId, uint256 tokenId, uint256 liquidity);
    event Unstaked(address indexed user, uint256 noteId, uint256 tokenId);
    event RewardClaimed(address indexed user, uint256 reward);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(
        IERC20 _rewardsToken,
        INonfungiblePositionManager _positionManager,
        IDyadXP _dyadXP,
        DNft _dnft, 
        uint256 _rewardsRate,
        address _rewardsTokenHolder, 
        address _token0,
        address _token1,
        uint24 _poolFee
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);

        rewardsToken = _rewardsToken;
        positionManager = _positionManager;
        dyadXP = _dyadXP; 
        dnft = _dnft;
        rewardsRate = _rewardsRate;
        rewardsTokenHolder = _rewardsTokenHolder;
        
        token0 = _token0;
        token1 = _token1;
        poolFee = _poolFee;
    }

    function stake(uint256 noteId, uint256 tokenId) external {
        require(dnft.ownerOf(noteId) == msg.sender, "You are not the Note owner");

        StakeInfo storage stakeInfo = stakes[noteId];
        require(!stakeInfo.isStaked, "Note already used for staking"); 

        (
          , 
          , 
          address positionToken0, 
          address positionToken1, 
          uint24 positionFee, 
          , 
          , 
          uint128 liquidity, 
          , 
          ,
          , 
        ) = positionManager.positions(tokenId);

        require(liquidity > 0, "No liquidity");
        require(
          (positionToken0 == token0 && positionToken1 == token1) ||
          (positionToken0 == token1 && positionToken1 == token0),
          "Invalid token pair"
        );
        require(positionFee == poolFee, "Invalid fee");

        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        stakes[noteId] = StakeInfo({
          liquidity: liquidity,
          lastRewardTime: block.timestamp,
          tokenId: tokenId,
          isStaked: true
        });

        emit Staked(msg.sender, noteId, tokenId, liquidity);
    }

    function unstake(uint256 noteId, address recipient) external {
        StakeInfo storage stakeInfo = stakes[noteId];

        _claimRewards(noteId, stakeInfo, recipient);

        positionManager.safeTransferFrom(address(this), msg.sender, stakeInfo.tokenId);

        delete stakes[noteId];

        emit Unstaked(msg.sender, noteId, stakeInfo.tokenId);
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

        return timeDiff * rewardsRate * stakeInfo.liquidity / 1e18 * xp / 1e18;
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

    function setPoolParameters(address _token0, address _token1, uint24 _poolFee) external onlyOwner {
      token0 = _token0;
      token1 = _token1;
      poolFee = _poolFee;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
