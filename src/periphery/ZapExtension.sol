// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DNft} from "../core/DNft.sol";
import {VaultManagerV5} from "../core/VaultManagerV5.sol";
import {VaultLicenser} from "../core/VaultLicenser.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IExtension} from "../interfaces/IExtension.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

contract ZapExtension is IExtension {
    using SafeTransferLib for ERC20;

    DNft public immutable dNft;
    address public immutable augustusSwapper;
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

    event WithdrawnAndSwapped(
        uint256 indexed tokenId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address vault
    );

    constructor(address _dNft, address _augustusSwapper, address _vaultManager, address _vaultLicenser) {
        dNft = DNft(_dNft);
        augustusSwapper = _augustusSwapper;
        vaultManager = VaultManagerV5(_vaultManager);
        vaultLicenser = VaultLicenser(_vaultLicenser);
    }

    function name() external pure override returns (string memory) {
        return "Zap Extension";
    }

    function description() external pure override returns (string memory) {
        return "Extension for zapping in and out of vaults using a swap of any token";
    }

    function getHookFlags() external pure override returns (uint256) {
        return 0; // No hooks needed for this extension
    }

    function zapIn(
        uint256 tokenId,
        address tokenIn,
        address vault,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes calldata swapData
    ) external {
        require(dNft.ownerOf(tokenId) == msg.sender, NotDNftOwner());
        require(vaultLicenser.isLicensed(vault), UnlicensedVault());

        ERC20 asset = IVault(vault).asset();

        ERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 balance = ERC20(tokenIn).balanceOf(address(this));

        ERC20(tokenIn).safeApprove(augustusSwapper, balance);

        (bool success, bytes memory returnData) = address(augustusSwapper).call(swapData);
        require(success, SwapFailed());

        (uint256 receivedAmount,,) = abi.decode(returnData, (uint256, uint256, uint256));

        require(receivedAmount >= minAmountOut, InsufficientAmountOut());

        asset.safeApprove(address(vaultManager), receivedAmount);

        vaultManager.deposit(tokenId, vault, receivedAmount);

        emit SwappedAndDeposited(tokenId, tokenIn, address(asset), amountIn, receivedAmount, vault);
    }

    function zapOut(
        uint256 tokenId,
        address tokenOut,
        address vault,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes calldata swapData
    ) external {
        require(dNft.ownerOf(tokenId) == msg.sender, NotDNftOwner());
        require(vaultLicenser.isLicensed(vault), UnlicensedVault());

        ERC20 asset = IVault(vault).asset();

        vaultManager.withdraw(tokenId, vault, amountIn, address(this));
        asset.approve(augustusSwapper, amountIn);

        (bool success, bytes memory returnData) = address(augustusSwapper).call(swapData);
        require(success, SwapFailed());

        (uint256 receivedAmount,,) = abi.decode(returnData, (uint256, uint256, uint256));

        require(receivedAmount >= minAmountOut, InsufficientAmountOut());

        ERC20(tokenOut).safeTransfer(msg.sender, receivedAmount);

        emit WithdrawnAndSwapped(tokenId, address(asset), tokenOut, amountIn, receivedAmount, vault);
    }
}
