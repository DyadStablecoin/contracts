// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IExtension} from "../interfaces/IExtension.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

contract RedeemCollateralExtension is IExtension {
    error NotDnftOwner();
    error WithdrawFailed();
    error InvalidOperation();

    IERC20 public immutable dyad;
    IERC721 public immutable dNft;
    IVaultManager public immutable vaultManager;

    constructor(address _dyad, address _dNft, address _vaultManager) {
        dyad = IERC20(_dyad);
        dNft = IERC721(_dNft);
        vaultManager = IVaultManager(_vaultManager);
    }

    function name() external pure override returns (string memory) {
        return "Collateral Redeemer";
    }

    function description() external pure override returns (string memory) {
        return "Extension for redeeming DYAD for underlying collateral";
    }

    function getHookFlags() external pure override returns (uint256) {
        // no hooks needed for this extension
        return 0;
    }

    /**
     * @notice Redeem DYAD through a dNFT
     * @param id The ID of the dNFT for which the DYAD is being redeemed.
     * @param vault Address of the vault through which the DYAD is being redeemed
     *        for its underlying collateral.
     * @param amount The amount of DYAD to be redeemed.
     * @param to The address where the collateral will be sent.
     * @return The amount of collateral that was redeemed.
     */
    function redeemDyad(uint256 id, address vault, uint256 amount, address to) external returns (uint256) {
        if (dNft.ownerOf(id) != msg.sender) {
            revert NotDnftOwner();
        }

        dyad.transferFrom(msg.sender, address(this), amount);
        vaultManager.burnDyad(id, amount);
        IVault _vault = IVault(vault);
        uint256 redeemedAmount =
            amount * (10 ** (_vault.oracle().decimals() + _vault.asset().decimals())) / _vault.assetPrice() / 1e18;
        vaultManager.withdraw(id, vault, redeemedAmount, to);

        return redeemedAmount;
    }
}
