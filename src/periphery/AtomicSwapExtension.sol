// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IExtension, IAfterWithdrawHook} from "../interfaces/IExtension.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IVault} from "../interfaces/IVault.sol";
import {DyadHooks} from "../core/DyadHooks.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract AtomicSwapExtension is IExtension, IAfterWithdrawHook {
    using SafeTransferLib for ERC20;

    error SwapFailed();

    address public constant AUGUSTUS_6_2 = 0x6A000F20005980200259B80c5102003040001068;
    IVaultManager public immutable vaultManager;

    constructor(address _vaultManager) {
        vaultManager = IVaultManager(_vaultManager);
    }

    function name() external pure returns (string memory) {
        return "Atomic Swap";
    }

    function description() external pure returns (string memory) {
        return "Allows users to swap between collaterals atomically.";
    }

    function getHookFlags() external pure returns (uint256) {
        return DyadHooks.AFTER_WITHDRAW;
    }

    function swapCollateral(
        uint256 noteId,
        address fromVault,
        uint256 fromAmount,
        address toVault,
        uint256 toAmount,
        bytes calldata swapData
    ) external {
        // tstore swap data
        assembly {
            let size := calldatasize()
            let slot := 0
            for { let i := 0x64 } lt(i, size) { i := add(i, 0x20) } {
                tstore(slot, calldataload(i))
                slot := add(slot, 1)
            }
        }

        vaultManager.withdraw(noteId, fromVault, fromAmount, address(this));
    }

    function afterWithdraw(uint256 id, address vault, uint256 amount, address to) external {
        uint256 numberOfSlots;
        address toVault;
        uint256 toAmount;
        bytes memory swapData;
        assembly {
            // toVault should be the first transient slot
            toVault := tload(0)
            // toAmount should be the second transient slot
            toAmount := tload(1)
            // allocate swapData in memory
            swapData := mload(0x40)
            let i := 1
            // load the size of the addresses array from the fourth transient slot
            // we skip the third slot because it's the offset in calldata and we don't need that
            let swapDataSize := tload(3)
            // store the size of the swapData in the first slot of the memory array
            mstore(swapData, swapDataSize)
            // iterate over the addresses and copy them into the memory array
            for {} lt(sub(i, 1), swapDataSize) { i := add(i, 1) } {
                // copy from transient storage into memory
                mstore(add(swapData, mul(i, 0x20)), tload(add(i, 3)))
            }
            // update the free memory pointer
            mstore(0x40, add(swapData, mul(sub(i, 1), 0x20)))
        }

        IVault(vault).asset().safeApprove(AUGUSTUS_6_2, amount);

        (bool success, bytes memory data) = AUGUSTUS_6_2.call(swapData);
        // ensure swap was successful
        require(success, SwapFailed());

        (uint256 amountOut,,) = abi.decode(data, (uint256, uint256, uint256));
        // check if the amountOut is greater than or equal to the expected amount
        require(amountOut >= toAmount, SwapFailed());

        // approve the asset and deposit
        IVault(toVault).asset().safeApprove(address(vaultManager), amountOut);
        vaultManager.deposit(id, toVault, amountOut);
    }
}
