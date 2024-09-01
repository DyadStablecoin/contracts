// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExtension {
    function name() external view returns (string memory);
    function description() external view returns (string memory);
    function getHookFlags() external view returns (uint256);
}

interface IAfterDepositHook is IExtension{
    function afterDeposit(uint256 id, address vault, uint256 amount) external;
}

interface IAfterWithdrawHook is IExtension {
    function afterWithdraw(uint256 id, address vault, uint256 amount, address to) external;
}

interface IAfterMintHook is IExtension {
    function afterMint(uint256 id, uint256 amount, address to) external;
}

interface IAfterBurnHook is IExtension {
    function afterBurn(uint256 id, uint256 amount) external;
}

