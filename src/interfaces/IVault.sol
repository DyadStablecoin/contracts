// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;

interface IVault {
  event Withdraw (uint indexed from, address indexed to, uint amount);
  event Deposit  (uint indexed id, uint amount);

  error StaleData            ();
  error IncompleteRound      ();
  error NotVaultManager      ();
}
