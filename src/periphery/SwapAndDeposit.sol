// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IExtension} from "../interfaces/IExtension.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract SwapAndDeposit is IExtension {
  IERC20 public immutable kerosene;

  constructor(address _kerosene) {
    kerosene = IERC20(_kerosene);
  }

  function name() external pure override returns (string memory) {
    return "Swap and Deposit";
  }

  function description() external pure override returns (string memory) {
    return "Extension for swapping to Kerosene and directly depositing in a Note";
  }

  function getHookFlags() external pure override returns (uint256) {
      // no hooks needed for this extension
      return 0;
  }

  function swapToKerosene(
      address tokenIn,
      uint256 amountIn,
      uint256 amountOutMin,
      uint24 fee1,
      uint24 fee2,
      address to
  ) external {
      // Transfer the input tokens from the sender to this contract
      IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

      // Approve the Uniswap router to spend the input tokens
      IERC20(tokenIn).approve(address(swapRouter), amountIn);

      // Determine the path for the swap
      bytes memory path;
      address WETH9 = swapRouter.WETH9();

      if (tokenIn == address(keroseneToken)) {
          // No swap needed if tokenIn is already Kerosene
          keroseneToken.transfer(to, amountIn);
          return;
      }

      if (tokenIn == WETH9 || address(keroseneToken) == WETH9) {
          // Single-hop swap
          path = abi.encodePacked(tokenIn, fee1, address(keroseneToken));
      } else {
          // Multi-hop swap via WETH9
          path = abi.encodePacked(tokenIn, fee1, WETH9, fee2, address(keroseneToken));
      }

      // Set up the swap parameters
      ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
          path: path,
          recipient: to,
          deadline: block.timestamp + 15, // Using a 15-second deadline for safety
          amountIn: amountIn,
          amountOutMinimum: amountOutMin
      });

      // Execute the swap
      swapRouter.exactInput(params);
  }
}
