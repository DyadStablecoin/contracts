// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IExtension} from "../interfaces/IExtension.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
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

    function depositNative(uint256 id) external payable {
        if (dNft.ownerOf(id) != msg.sender) {
            revert NotDnftOwner();
        }
        weth.deposit{value: msg.value}();
        //weth.approve(address(vaultManager), msg.value);
        vaultManager.deposit(id, wethVault, msg.value);
    }

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

    function redeemNative(uint256 id, uint256 amount, address to) external {
        if (dNft.ownerOf(id) != msg.sender) {
            revert NotDnftOwner();
        }

        dyad.transferFrom(msg.sender, address(this), amount);
        //dyad.approve(address(vaultManager), amount);
        uint256 redeemedAmount = vaultManager.redeemDyad(id, wethVault, amount, address(this));
        weth.withdraw(redeemedAmount);
        (bool success,) = to.call{value: redeemedAmount}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }

    function afterDeposit(uint256, address, uint256) external {
        // Do nothing
    }
    function afterWithdraw(uint256, address, uint256, address) external {
        // Do nothing
    }

    function afterMint(uint256, uint256, address) external pure {
        revert InvalidOperation();
    }

    function afterBurn(uint256, uint256) external pure {
        revert InvalidOperation();
    }

    function afterRedeem(uint256, address, uint256, address, uint256) external {
        // Do nothing
    }

    receive() external payable {
        if (msg.sender != address(weth)) {
            revert InvalidOperation();
        }
    }
}
