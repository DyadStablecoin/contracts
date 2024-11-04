// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DNft} from "../core/DNft.sol";
import {VaultManagerV5} from "../core/VaultManagerV5.sol";
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
  address public immutable wethVault;
  VaultManagerV5 public immutable vaultManager;

  error NotDnftOwner();

  event SwappedAndDeposited(uint tokenId, address tokenIn, uint256 amountIn, uint256 amountOut);

  constructor(
    address _dNft,
    address _kerosene,
    address _swapRouter,
    address _WETH9,
    address _wethVault,
    address _vaultManager
  ) {
    dNft = DNft(_dNft);
    kerosene = ERC20(_kerosene);
    swapRouter = ISwapRouter(_swapRouter);
    WETH9 = _WETH9;
    wethVault = _wethVault;
    vaultManager = VaultManagerV5(_vaultManager);
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

  function _swapToKerosene(
      address tokenIn,
      uint256 amountIn,
      uint256 amountOutMin,
      uint24 fee1,
      uint24 fee2,
      address to
  ) internal returns (uint amountOut) {
      require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
      require(tokenIn != address(kerosene), "INVALID_PATH");

      // Transfer the input tokens from the sender to this contract
      ERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

      // Approve the Uniswap router to spend the input tokens
      ERC20(tokenIn).approve(address(swapRouter), amountIn);

      bytes memory path;

      if (tokenIn == WETH9) {
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
      amountOut = swapRouter.exactInput(params);
  }

  function swapAndDeposit(
      uint tokenId,
      address tokenIn,
      uint256 amountIn,
      uint256 amountOutMin,
      uint24 fee1,
      uint24 fee2
  ) external nonReentrant {
      if (dNft.ownerOf(tokenId) != msg.sender) {
        revert NotDnftOwner();
      }
      uint amountSwapped = _swapToKerosene(tokenIn, amountIn, amountOutMin, fee1, fee2, address(this));
      kerosene.approve(address(vaultManager), amountSwapped);
      vaultManager.deposit(tokenId, wethVault, amountSwapped);
      emit SwappedAndDeposited(tokenId, tokenIn, amountIn, amountSwapped);
  }
}
