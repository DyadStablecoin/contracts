// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DNft} from "../core/DNft.sol";
import {VaultManagerV5} from "../core/VaultManagerV5.sol";
import {VaultLicenser} from "../core/VaultLicenser.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IExtension} from "../interfaces/IExtension.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SwapAndDeposit is IExtension, ReentrancyGuard {
  using SafeTransferLib for ERC20;

  DNft public immutable dNft;
  ERC20 public immutable kerosene;
  ISwapRouter public immutable swapRouter;
  address public immutable WETH9;
  VaultManagerV5 public immutable vaultManager;
  VaultLicenser public immutable vaultLicenser;

  event SwappedAndDeposited(
    uint tokenId,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut,
    address vault
  );

  constructor(
    address _dNft,
    address _kerosene,
    address _swapRouter,
    address _WETH9,
    address _vaultManager,
    address _vaultLicenser
  ) {
    dNft = DNft(_dNft);
    kerosene = ERC20(_kerosene);
    swapRouter = ISwapRouter(_swapRouter);
    WETH9 = _WETH9;
    vaultManager = VaultManagerV5(_vaultManager);
    vaultLicenser = VaultLicenser(_vaultLicenser);
  }

  function name() external pure override returns (string memory) {
    return "Swap and Deposit";
  }

  function description() external pure override returns (string memory) {
    return "Extension for swapping to Kerosene and directly depositing in a Note";
  }

  function getHookFlags() external pure override returns (uint256) {
      return 0; // no hooks needed for this extension
  }

  function _swapToCollateral(
      address tokenIn,
      address tokenOut, 
      uint256 amountIn,
      uint256 amountOutMin,
      uint24 fee1,
      uint24 fee2
  ) internal returns (uint amountOut) {
      // Transfer the input tokens from the sender to this contract
      ERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

      // Approve the Uniswap router to spend the input tokens
      ERC20(tokenIn).approve(address(swapRouter), amountIn);

      bytes memory path;

      if (tokenIn == WETH9) {
          // Single-hop swap
          path = abi.encodePacked(tokenIn, fee1, tokenOut);
      } else {
          // Multi-hop swap via WETH9
          path = abi.encodePacked(tokenIn, fee1, WETH9, fee2, tokenOut);
      }

      // Set up the swap parameters
      ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
          path: path,
          recipient: address(this),
          deadline: block.timestamp + 15, // Using a 15-second deadline for safety
          amountIn: amountIn,
          amountOutMinimum: amountOutMin
      });

      // Execute the swap
      amountOut = swapRouter.exactInput(params);
  }

  function swapAndDeposit(
      uint tokenId,
      address tokenIn,
      address vault,
      uint256 amountIn,
      uint256 amountOutMin,
      uint24 fee1,
      uint24 fee2
  ) external nonReentrant {
      require(dNft.ownerOf(tokenId) == msg.sender, "NOT_DNFT_OWNER");
      require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
      require(amountOutMin > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
      require(vaultLicenser.isLicensed(vault), "UNLICENSED_VAULT");
      ERC20 asset = IVault(vault).asset();
      require(address(asset) != tokenIn, "SAME_TOKEN");
      uint amountSwapped = _swapToCollateral(
        tokenIn,
        address(asset),
        amountIn,
        amountOutMin,
        fee1,
        fee2
      );
      asset.approve(address(vaultManager), amountSwapped);
      vaultManager.deposit(tokenId, vault, amountSwapped);
      emit SwappedAndDeposited(tokenId, tokenIn, address(asset), amountIn, amountSwapped, vault);
  }
}
