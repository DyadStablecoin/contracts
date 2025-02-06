// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IInterestVault {
    function mintInterest(address _to, uint256 _amount) external;
    function notifyBurnableInterest(uint256 _amount) external;
}
