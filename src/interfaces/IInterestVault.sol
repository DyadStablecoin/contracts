// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IInterestVault {
    function mintInterest(uint256 _amount) external;
}
