// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IDyad {

  error NotLicensed();
  error DNftDoesNotExist();

 /**
  * @notice Mints amount of DYAD through a dNFT and licensed vault manager 
  *         to a specified address.
  * @dev The caller must be a licensed vault manager. Vault manager get
  *      licensed by the 'sll'.
  * @param id ID of the dNFT.
  * @param to The address of the recipient who will receive the tokens.
  * @param amount The amount of tokens to be minted.
  */
  function mint(
      uint    id, 
      address to,
      uint    amount
  ) external;

 /**
  * @notice Burns amount of DYAD through a dNFT and licensed vault manager
  *         from a specified address.
  * @dev The caller must be a licensed vault manager. Vault manager get
  *      licensed by the 'sll'.
  * @param id ID of the dNFT.
  * @param from The address of the recipient who the tokens will be burnt
  *        from.
  * @param amount The amount of tokens to be burned.
  */
  function burn(
      uint    id, 
      address from,
      uint    amount
  ) external;
}
