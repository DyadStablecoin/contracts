// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IExtension} from "../interfaces/IExtension.sol";
import {ICurvePool} from "../interfaces/ICurvePool.sol";
import {IDyadLPStaking} from "../interfaces/IDyadLPStaking.sol";
import {DNft} from "../core/DNft.sol";
import {VaultManagerV5} from "../core/VaultManagerV5.sol";
import {Dyad} from "../core/Dyad.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

contract MintAndStake is IExtension, ReentrancyGuard {
    using SafeTransferLib for ERC20;

    DNft public immutable dNft;
    VaultManagerV5 public immutable vaultManager;
    Dyad public immutable dyad;

    error NotDNftOwner();

    constructor(address _dNft, address _vaultManager, address _dyad) {
        dNft = DNft(_dNft);
        vaultManager = VaultManagerV5(_vaultManager);
        dyad = Dyad(_dyad);
    }

    function name() external pure override returns (string memory) {
        return "Mint and Stake";
    }

    function description() external pure override returns (string memory) {
        return "Mint DYAD, provide Liquidity, and stake LP tokens automatically";
    }

    function getHookFlags() external pure override returns (uint256) {
        return 0; // no hooks needed for this extension
    }

    function mintAndStake(
        uint256 tokenId,
        uint256 amount,
        address pool,
        uint256 dyadIndex,
        address stakingContract,
        uint256 minAmountOut
    ) external nonReentrant {
        if (dNft.ownerOf(tokenId) != msg.sender) {
            revert NotDNftOwner();
        }
        // mint dyad
        vaultManager.mintDyad(tokenId, amount, address(this));

        // add liquidity
        dyad.approve(pool, amount);
        uint256[] memory amounts = new uint256[](ICurvePool(pool).N_COINS());
        amounts[dyadIndex] = amount;
        uint256 lpAmount = ICurvePool(pool).add_liquidity(amounts, minAmountOut, address(this));

        // stake LP tokens
        ERC20(address(pool)).approve(stakingContract, lpAmount);
        IDyadLPStaking(stakingContract).deposit(tokenId, lpAmount);
    }

    // THIS NEEDS 2 APPROVALS, ONE FOR THE STAKING CONTRACT AND ONE FOR THE POOL
    // AND IS THEREFORE NOT VERY PRATICAL
    function unstakeAndBurn(
        uint256 tokenId,
        uint256 amount,
        address pool,
        uint256 dyadIndex,
        address stakingContract,
        uint256 minDyadOut
    ) external nonReentrant {
        if (dNft.ownerOf(tokenId) != msg.sender) {
            revert NotDNftOwner();
        }
        // Unstake LP tokens (LP tokens are sent to msg.sender)
        IDyadLPStaking(stakingContract).withdraw(tokenId, amount);

        ERC20(pool).safeTransferFrom(msg.sender, address(this), amount);

        // Remove liquidity (DYAD tokens are sent to msg.sender)
        uint256 dyadAmount =
            ICurvePool(pool).remove_liquidity_one_coin(amount, int128(int256(dyadIndex)), minDyadOut, msg.sender);

        vaultManager.burnDyad(tokenId, dyadAmount);
    }
}
