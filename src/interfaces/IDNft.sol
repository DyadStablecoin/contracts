// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IDNft {
  event MintedNft       (uint indexed id, address indexed to);
  event MintedInsiderNft(uint indexed id, address indexed to);
  event Drained         (address indexed to, uint amount);

  error InsiderMintsExceeded ();
  error InsufficientFunds    ();

  /**
   * @dev Mints an dNFT and transfers it to the given `to` address.
   * 
   * Requirements:
   * - msg.value exceeds the minting price
   *
   * Emits a {MintedNft} event on successful execution.
   *
   * @param to The address to which the minted NFT will be transferred.
   * @return id The ID of the minted NFT.
   *
   * Throws a {InsufficientFunds} error if the sender does not provide enough ETH to mint the NFT.
   */
  function mintNft(address to) external payable returns (uint id);

  /**
   * @notice Mint new insider DNft to `to` 
   * @dev Note:
   *      - An insider dNFT does not require buring ETH to mint
   * @dev Will revert:
   *      - If not called by contract owner
   *      - If the maximum number of insider mints has been reached
   *      - If `to` is the zero address
   * @dev Emits:
   *      - MintNft(address indexed to, uint indexed id)
   * @param to The address to mint the dNFT to
   * @return id Id of the new dNFT
   * 
   * Throws a {InsiderMintsExceeded} error if the maximum number of insider mints has been reached.
   */
  function mintInsiderNft(address to) external returns (uint id);

  /**
   * @notice Drain the contract balance to `to`
   * @dev Will revert:
   *      - If not called by contract owner
   * @dev Emits:
   *      - Drained(address indexed to, uint amount)
   * @param to The address to drain the contract balance to
   */
  function drain(address to) external;
}
