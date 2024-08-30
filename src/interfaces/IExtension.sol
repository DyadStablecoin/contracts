// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExtension {
    function name() external view returns (string memory);
    function description() external view returns (string memory);
    function afterDeposit(uint256 id, address vault, uint256 amount) external;
    function afterWithdraw(uint256 id, address vault, uint256 amount, address to) external;
    function afterMint(uint256 id, uint256 amount, address to) external;
    function afterBurn(uint256 id, uint256 amount) external;
    function afterRedeem(uint256 id, address vault, uint256 amount, address to, uint256 assetAmount) external;
}