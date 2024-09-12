// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVaultManagerV5 {
  event Added     (uint indexed id, address indexed vault);
  event Removed   (uint indexed id, address indexed vault);
  event MintDyad  (uint indexed id, uint amount, address indexed to);
  event BurnDyad  (uint indexed id, uint amount, address indexed from);
  event RedeemDyad(uint indexed id, address indexed vault, uint amount, address indexed to);
  event Liquidate (uint indexed id, address indexed from, uint indexed to, uint amount);
  event SystemExtensionAuthorized(address indexed extension, uint256 hooks);
  event UserExtensionAuthorized(address indexed user, address indexed extension, bool indexed authorized);

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
  error Unauthorized();

  /**
   * @notice Adds a vault to the dNFT position
   * @param id The ID of the dNFT for which the vault is being added.
   * @param vault The address of the vault contract to be added.
   */
  function add(uint id, address vault) external;

  /**
   * @notice Removes a vault from the dNFT position
   * @param id The ID of the dNFT for which the vault is being removed.
   * @param vault The address of the vault contract to be removed.
   */
  function remove(uint id, address vault) external;

  /**
   * @notice Allows a dNFT owner to deposit collateral into a vault
   * @param id The ID of the dNFT for which the deposit is being made.
   * @param vault The vault where the assets will be deposited.
   * @param amount The amount of assets to be deposited.
   */
  function deposit(uint id, address vault, uint amount) external;

  /**
   * @notice Allows a dNFT owner to withdraw collateral from a vault
   * @param id The ID of the dNFT for which the withdraw is being made.
   * @param vault The vault where the assets will be deposited.
   * @param amount The amount of assets to be deposited.
   * @param to The address where the assets will be sent.
   */
  function withdraw(uint id, address vault, uint amount, address to) external;

  /**
   * @notice Mint DYAD through a dNFT
   * @param id The ID of the dNFT for which the DYAD is being minted.
   * @param amount The amount of DYAD to be minted.
   * @param to The address where the DYAD will be sent.
   */
  function mintDyad(uint id, uint amount, address to) external;

  /**
   * @notice Burn DYAD through a dNFT
   * @param id The ID of the dNFT for which the DYAD is being burned.
   * @param amount The amount of DYAD to be burned.
   */
  function burnDyad(uint id, uint amount) external;
}
