// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExtension {
    function name() external view returns (string memory);
    function description() external view returns (string memory);
    function afterDeposit() external;
    function afterWithdraw() external;
    function afterMint() external;
    function afterBurn() external;
    function afterRedeem(uint256 assetAmount) external;
}