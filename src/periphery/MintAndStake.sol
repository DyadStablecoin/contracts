// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IExtension} from "../interfaces/IExtension.sol";
import {ICurvePool} from "../interfaces/ICurvePool.sol";
import {IDyadLPStaking} from "../interfaces/IDyadLPStaking.sol";
import {DNft} from "../core/DNft.sol";
import {VaultManagerV5} from "../core/VaultManagerV5.sol";
import {Dyad} from "../core/Dyad.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MintAndStake is IExtension, ReentrancyGuard {
  DNft public immutable dNft;
  VaultManagerV5 public immutable vaultManager;
  Dyad public immutable dyad;

  constructor(
    address _dNft,
    address _vaultManager,
    address _dyad
  ) {
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
      uint tokenId,
      uint amount,
      address pool,
      uint dyadIndex,
      address stakingContract,
      uint minAmountOut
  ) external nonReentrant {
      require(dNft.ownerOf(tokenId) == msg.sender, "NOT_DNFT_OWNER");
      // mint dyad
      vaultManager.mintDyad(tokenId, amount, address(this));

      // add liquidity
      dyad.approve(pool, amount);
      uint256[] memory amounts = new uint256[](ICurvePool(pool).N_COINS());
      amounts[dyadIndex] = amount;
      uint lpAmount = ICurvePool(pool).add_liquidity(amounts, minAmountOut, address(this));

      // stake LP tokens
      IERC20(address(pool)).approve(stakingContract, lpAmount);
      IDyadLPStaking(stakingContract).deposit(tokenId, lpAmount);
  }
}
