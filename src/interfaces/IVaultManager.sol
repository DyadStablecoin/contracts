// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVaultManager {
    event Added(uint256 indexed id, address indexed vault);
    event Removed(uint256 indexed id, address indexed vault);
    event MintDyad(uint256 indexed id, uint256 amount, address indexed to);
    event BurnDyad(uint256 indexed id, uint256 amount, address indexed from);
    event RedeemDyad(uint256 indexed id, address indexed vault, uint256 amount, address indexed to);
    event Liquidate(uint256 indexed id, address indexed from, uint256 indexed to);

    error NotOwner();
    error NotLicensed();
    error VaultNotLicensed();
    error TooManyVaults();
    error VaultAlreadyAdded();
    error VaultNotAdded();
    error VaultHasAssets();
    error NotDNftVault();
    error InvalidDNft();
    error CrTooLow();
    error CrTooHigh();
    error CanNotWithdrawInSameBlock();
    error NotEnoughExoCollat();
    error VaultNotKerosene();

    /**
     * @notice Adds a vault to the dNFT position
     * @param id The ID of the dNFT for which the vault is being added.
     * @param vault The address of the vault contract to be added.
     */
    function add(uint256 id, address vault) external;

    /**
     * @notice Removes a vault from the dNFT position
     * @param id The ID of the dNFT for which the vault is being removed.
     * @param vault The address of the vault contract to be removed.
     */
    function remove(uint256 id, address vault) external;

    /**
     * @notice Allows a dNFT owner to deposit collateral into a vault
     * @param id The ID of the dNFT for which the deposit is being made.
     * @param vault The vault where the assets will be deposited.
     * @param amount The amount of assets to be deposited.
     */
    function deposit(uint256 id, address vault, uint256 amount) external;

    /**
     * @notice Allows a dNFT owner to withdraw collateral from a vault
     * @param id The ID of the dNFT for which the withdraw is being made.
     * @param vault The vault where the assets will be deposited.
     * @param amount The amount of assets to be deposited.
     * @param to The address where the assets will be sent.
     */
    function withdraw(uint256 id, address vault, uint256 amount, address to) external;

    /**
     * @notice Mint DYAD through a dNFT
     * @param id The ID of the dNFT for which the DYAD is being minted.
     * @param amount The amount of DYAD to be minted.
     * @param to The address where the DYAD will be sent.
     */
    function mintDyad(uint256 id, uint256 amount, address to) external;

    /**
     * @notice Burn DYAD through a dNFT
     * @param id The ID of the dNFT for which the DYAD is being burned.
     * @param amount The amount of DYAD to be burned.
     */
    function burnDyad(uint256 id, uint256 amount) external;

    /**
     * @notice Redeem DYAD through a dNFT
     * @param id The ID of the dNFT for which the DYAD is being redeemed.
     * @param vault Address of the vault through which the DYAD is being redeemed
     *        for its underlying collateral.
     * @param amount The amount of DYAD to be redeemed.
     * @param to The address where the collateral will be sent.
     * @return The amount of collateral that was redeemed.
     */
    function redeemDyad(uint256 id, address vault, uint256 amount, address to) external returns (uint256);

    /**
     * @notice Liquidate a dNFT
     * @param id The ID of the dNFT to be liquidated.
     * @param to The address where the collateral will be sent.
     */
    // function liquidate(uint id, uint to, uint amount) external;
}
