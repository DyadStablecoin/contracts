// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DNft} from "../core/DNft.sol";
import {VaultManagerV5} from "../core/VaultManagerV5.sol";
import {VaultLicenser} from "../core/VaultLicenser.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IExtension} from "../interfaces/IExtension.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IAugustusSwapper {
    function getTokenTransferProxy() external view returns (address);
}

contract SwapAndDeposit is IExtension, ReentrancyGuard {
    using SafeTransferLib for ERC20;

    DNft public immutable dNft;
    IAugustusSwapper public immutable augustusSwapper;
    VaultManagerV5 public immutable vaultManager;
    VaultLicenser public immutable vaultLicenser;

    error NotDNftOwner();
    error UnlicensedVault();
    error SwapFailed();
    error InsufficientAmountOut();

    event SwappedAndDeposited(
        uint256 indexed tokenId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address vault
    );

    constructor(address _dNft, address _augustusSwapper, address _vaultManager, address _vaultLicenser) {
        dNft = DNft(_dNft);
        augustusSwapper = IAugustusSwapper(_augustusSwapper);
        vaultManager = VaultManagerV5(_vaultManager);
        vaultLicenser = VaultLicenser(_vaultLicenser);
    }

    function name() external pure override returns (string memory) {
        return "Swap and Deposit";
    }

    function description() external pure override returns (string memory) {
        return "Extension for swapping to a vault's asset and directly depositing into a Note";
    }

    function getHookFlags() external pure override returns (uint256) {
        return 0; // No hooks needed for this extension
    }

    receive() external payable {}

    function _swapToCollateral(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes calldata callData,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        // Transfer tokenIn from the user to this contract, handling fee-on-transfer tokens
        uint256 balanceBefore = ERC20(tokenIn).balanceOf(address(this));
        ERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 balanceAfter = ERC20(tokenIn).balanceOf(address(this));
        uint256 actualAmountIn = balanceAfter - balanceBefore;

        // Approve the tokenTransferProxy to spend tokenIn using the safe approval pattern
        address tokenTransferProxy = augustusSwapper.getTokenTransferProxy();
        ERC20(tokenIn).safeApprove(tokenTransferProxy, 0);
        ERC20(tokenIn).safeApprove(tokenTransferProxy, actualAmountIn);

        // Record balance of tokenOut before swap
        uint256 tokenOutBalanceBefore = ERC20(tokenOut).balanceOf(address(this));

        (bool success, ) = address(augustusSwapper).call(callData);
        require(success, SwapFailed());

        // Get the amountOut by checking the balance of the tokenOut after the swap
        uint256 tokenOutBalanceAfter = ERC20(tokenOut).balanceOf(address(this));
        amountOut = tokenOutBalanceAfter - tokenOutBalanceBefore;

        if (amountOut < minAmountOut) revert InsufficientAmountOut();
    }

    function swapAndDeposit(
        uint256 tokenId,
        address tokenIn,
        address vault,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes calldata callData
    ) external nonReentrant {
        if (dNft.ownerOf(tokenId) != msg.sender) revert NotDNftOwner();
        if (!vaultLicenser.isLicensed(vault)) revert UnlicensedVault();

        ERC20 asset = IVault(vault).asset();

        uint256 amountSwapped = _swapToCollateral(tokenIn, amountIn, minAmountOut, callData, address(asset));

        // Approve the vaultManager to spend the swapped tokens using the safe approval pattern
        asset.safeApprove(address(vaultManager), 0);
        asset.safeApprove(address(vaultManager), amountSwapped);

        vaultManager.deposit(tokenId, vault, amountSwapped);

        emit SwappedAndDeposited(tokenId, tokenIn, address(asset), amountIn, amountSwapped, vault);
    }
}
