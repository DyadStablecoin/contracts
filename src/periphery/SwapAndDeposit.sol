// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DNft} from "../core/DNft.sol";
import {VaultManagerV5} from "../core/VaultManagerV5.sol";
import {IExtension} from "../interfaces/IExtension.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract SwapAndDeposit is IExtension {
  DNft public immutable dNft;
  IERC20 public immutable kerosene;
  ISwapRouter public immutable swapRouter;
  address public immutable WETH9;
  address public immutable wethVault;
  VaultManagerV5 public immutable vaultManager;

  error NotDnftOwner();

  constructor(
    address _dNft,
    address _kerosene,
    address _swapRouter,
    address _WETH9,
    address _wethVault,
    address _vaultManager
  ) {
    dNft = DNft(_dNft);
    kerosene = IERC20(_kerosene);
    swapRouter = ISwapRouter(_swapRouter);
    WETH9 = _WETH9;
    wethVault = _wethVault;
    vaultManager = VaultManagerV5(_vaultManager);
    kerosene.approve(_vaultManager, type(uint256).max);
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
  ) public {
      // Transfer the input tokens from the sender to this contract
      IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

      // Approve the Uniswap router to spend the input tokens
      IERC20(tokenIn).approve(address(swapRouter), amountIn);

      // Determine the path for the swap
      bytes memory path;

      if (tokenIn == address(kerosene)) {
          // No swap needed if tokenIn is already Kerosene
          kerosene.transfer(to, amountIn);
          return;
      }

      if (tokenIn == WETH9 || address(kerosene) == WETH9) {
          // Single-hop swap
          path = abi.encodePacked(tokenIn, fee1, address(kerosene));
      } else {
          // Multi-hop swap via WETH9
          path = abi.encodePacked(tokenIn, fee1, WETH9, fee2, address(kerosene));
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

  function swapAndDeposit(
      uint tokenId,
      address tokenIn,
      uint256 amountIn,
      uint256 amountOutMin,
      uint24 fee1,
      uint24 fee2
  ) external {
      if (dNft.ownerOf(tokenId) != msg.sender) {
        revert NotDnftOwner();
      }
      swapToKerosene(tokenIn, amountIn, amountOutMin, fee1, fee2, address(this));
      vaultManager.deposit(tokenId, wethVault, kerosene.balanceOf(address(this)));
  }
}
