// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IExtension} from "../interfaces/IExtension.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

contract WETHGateway is IExtension {
    error NotDnftOwner();
    error WithdrawFailed();
    error InvalidOperation();

    IERC20 public immutable dyad;
    IERC721 public immutable dNft;
    IWETH public immutable weth;
    IVaultManager public immutable vaultManager;
    address public immutable wethVault;

    constructor(address _dyad, address _dNft, address _weth, address _vaultManager, address _wethVault) {
        dyad = IERC20(_dyad);
        dNft = IERC721(_dNft);
        weth = IWETH(_weth);
        vaultManager = IVaultManager(_vaultManager);
        wethVault = _wethVault;
        weth.approve(_vaultManager, type(uint256).max);
    }

    function name() external pure override returns (string memory) {
        return "Native Currency Gateway";
    }

    function description() external pure override returns (string memory) {
        return "Gateway for depositing and withdrawing native currency from the WETH Vault";
    }

    function getHookFlags() external pure override returns (uint256) {
        // no hooks needed for this extension
        return 0;
    }

    /// @notice Deposits native currency (ETH) into the WETH vault for a specific dNFT
    /// @dev Converts ETH to WETH and then deposits it into the vault
    /// @param id The ID of the dNFT to deposit for
    function depositNative(uint256 id) external payable {
        if (dNft.ownerOf(id) != msg.sender) {
            revert NotDnftOwner();
        }
        weth.deposit{value: msg.value}();
        vaultManager.deposit(id, wethVault, msg.value);
    }

    /// @notice Withdraws native currency (ETH) from the WETH vault for a specific dNFT
    /// @dev Converts WETH to ETH and transfers it to the specified address
    /// @param id The ID of the dNFT to withdraw from
    /// @param amount The amount of native currency to withdraw
    /// @param to The address to receive the withdrawn native currency
    function withdrawNative(uint256 id, uint256 amount, address to) external {
        if (dNft.ownerOf(id) != msg.sender) {
            revert NotDnftOwner();
        }
        vaultManager.withdraw(id, wethVault, amount, address(this));
        weth.withdraw(amount);
        (bool success,) = to.call{value: amount}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }

    /// @notice Redeems DYAD for native currency (ETH) from the WETH vault for a specific dNFT
    /// @dev Burns DYAD, withdraws corresponding WETH from the vault, converts it to ETH, and transfers to the specified address
    /// @param id The ID of the dNFT to redeem from
    /// @param amount The amount of DYAD to redeem
    /// @param to The address to receive the redeemed native currency
    function redeemNative(uint256 id, uint256 amount, address to) external {
        if (dNft.ownerOf(id) != msg.sender) {
            revert NotDnftOwner();
        }

        dyad.transferFrom(msg.sender, address(this), amount);
        vaultManager.burnDyad(id, amount);
        IVault vault = IVault(wethVault);
        uint256 redeemedAmount =
            amount * (10 ** (vault.oracle().decimals() + vault.asset().decimals())) / vault.assetPrice() / 1e18;
        vaultManager.withdraw(id, wethVault, redeemedAmount, address(this));
        weth.withdraw(redeemedAmount);
        (bool success,) = to.call{value: redeemedAmount}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }

    receive() external payable {
        if (msg.sender != address(weth)) {
            revert InvalidOperation();
        }
    }
}
