// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExtension {
    function afterDeposit() external;
    function afterWithdraw() external;
    function afterMint() external;
    function afterBurn() external;
    function afterRedeem(uint256 assetAmount) external;
}