// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IPermissionManager {
  enum Permission { MOVE, WITHDRAW, REDEEM }

  error MissingPermission();
  error NotOwner         ();

  event Granted(uint indexed id, OperatorPermission[] operatorPermission);

  struct OperatorPermission {
    address operator;
    Permission[] permissions; // Permissions given to the operator
  }

  struct NftPermission {
    uint8   permissions; // Bit map of the permissions
    uint248 lastUpdated; // The block number of the last permissions update
  }

  /**
   * @notice Check if `operator` has `permission` for dNFT with `id`
   * @notice All permissions for a given dNFT are revoked when the dNFT is 
   *         transferred. This is why we check for the last ownership change.
   *         This also means that we can not mint a DNft and grant it some
   *         permissions in the same block.
   * @param id Id of the dNFT
   * @param operator Operator to check the permission for
   * @param permission Permission to check for
   * @return True if operator has permission, false otherwise
   */
  function hasPermission(uint id, address operator, Permission permission) external returns (bool);
}
