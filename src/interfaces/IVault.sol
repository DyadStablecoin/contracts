// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;

interface IVault {
  event MintNft  (uint indexed id, address indexed to);
  event Withdraw (uint indexed from, address indexed to, uint amount);
  event MintDyad (uint indexed from, address indexed to, uint amount);
  event BurnDyad (uint indexed id, uint amount);
  event Liquidate(uint indexed id, address indexed to);
  event Redeem   (uint indexed from, uint amount, address indexed to, uint eth);
  event Grant    (uint indexed id, address indexed operator);
  event Revoke   (uint indexed id, address indexed operator);
  event Deposit  (uint indexed id, uint amount);

  error NotOwner             ();
  error StaleData            ();
  error CrTooLow             ();
  error CrTooHigh            ();
  error IncompleteRound      ();
  error PublicMintsExceeded  ();
  error InsiderMintsExceeded ();
  error MissingPermission    ();
  error IncorrectEthSacrifice();
  error TooMuchEth           ();
  error InvalidNft           ();

  /**
   * @notice Deposit ETH 
   * @dev Will revert:
   *      - If new deposit equals zero shares
   *      - If dNFT with id `id` does not exist
   * @dev Emits:
   *      - Deposit(uint indexed id, uint amount)
   * @dev For Auditors:
   *      - To save gas it does not check if `msg.value` is zero 
   * @param id Id of the dNFT that gets the deposited DYAD
   */
  function deposit(uint id) external payable;

  /**
   * @notice Withdraw ETH from dNFT
   * @dev Will revert:
   *      - If `msg.sender` is not the owner of the dNFT AND does not have 
   *        permission
   *      - If `amount` to withdraw is larger than the dNFT deposit
   *      - If Collateralization Ratio is is less than the min collaterization 
   *        ratio after the withdrawal
   * @dev Emits:
   *      - Withdraw(uint indexed from, address indexed to, uint amount)
   * @dev For Auditors:
   *      - To save gas it does not check if `amount` is 0 
   *      - To save gas it only fails implicitly if `from` does not have enough
   *        deposited ETH
   * @param from Id of the dNFT to withdraw from
   * @param to Address to send the ETH to
   * @param amount Amount of ETH to withdraw
   */
  function withdraw(uint from, address to, uint amount) external;

  /**
   * @notice Mint `amount` of DYAD as an ERC-20 token from dNFT
   * @dev Will revert:
   *      - If `msg.sender` is not the owner of the dNFT AND does not have 
   *        permission
   *      - If amount is larger than the dNFT ETH deposit
   *      - If Collateralization Ratio is is less than the min collaterization 
   *        ratio after the mint
   * @dev Emits:
   *      - MintDyad(uint indexed from, address indexed to, uint amount)
   * @dev For Auditors:
   *      - To save gas it does not check if `amount` is 0 
   * @param from Id of the dNFT to mint from
   * @param to Address to send the DYAD to
   * @param amount Amount of DYAD to mint
   */
  function mintDyad(uint from, address to, uint amount) external;

  /**
   * @notice Burn `amount` of DYAD 
   * @dev Will revert:
   *      - If dNFT with id `id` does not exist
   *      - If DYAD balance of dNFT is smaller than `amount`
   * @dev Emits:
   *      - BurnDyad(uint indexed from, address indexed to, uint amount)
   * @dev For Auditors:
   *      - To save gas it does not check if `amount` is 0 
   * @param id Id of the dNFT to mint from
   * @param amount Amount of DYAD to mint
   */
  function burnDyad(uint id, uint amount) external;

  /**
   * @notice Redeem DYAD ERC20 for ETH
   * @dev Will revert:
   *      - If DYAD to redeem is larger thatn `msg.sender` DYAD balance
   *      - If amount exceeds the dNFT DYAD balance
   *      - If amount of ETH exceeds the dNFT ETH balance
   *      - If the ETH transfer fails
   * @dev Emits:
   *      - Redeem(uint indexed from, address indexed to, uint amount)
   * @dev For Auditors:
   *      - To save gas it does not check if `amount` is 0 
   *      - `dyad.burn` is called in the beginning so we can revert as fast as
   *        possible if `msg.sender` does not have enough DYAD. The dyad contract
   *        is trusted so it introduces no re-entrancy risk. The revert is implicit
   *        and happens in the _burn function of the ERC20 contract as an underflow.
   *      - There is a re-entrancy risk while transfering the ETH, that is why the 
   *        `all state changes are done before the ETH transfer. I do not see why
   *        a `nonReentrant` modifier would be needed here, lets save the gas.
   * @param from dNFT to redeem from
   * @param to Address to send the ETH to
   * @param amount Amount of DYAD to redeem
   * @return eth Amount of ETH redeemed for DYAD
   */
  function redeem(uint from, address to, uint amount) external returns (uint);
}
