// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;

interface IVault {
  event Withdraw (uint indexed from, address indexed to, uint amount);
  event Deposit  (uint indexed id, uint amount);
  event Move     (uint indexed from, uint indexed to, uint amount);

  error StaleData            ();
  error IncompleteRound      ();
  error NotVaultManager      ();
}
