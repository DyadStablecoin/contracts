// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract Transit {
    function storeVariables(
        uint256, /* noteId */
        address, /* fromVault */
        uint256, /* fromAmount */
        address, /* toVault */
        uint256, /* toAmount */
        bytes calldata /* swapData */
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
    }

    function loadVariables() external view returns (uint256, uint256, bytes memory) {
        address toVault;
        uint256 toAmount;
        bytes memory swapData;

        uint256 oldFMP;
        uint256 newFMP;

        assembly {
            oldFMP := mload(0x40)
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
            for {} lt(mul(sub(i, 1), 0x20), swapDataSize) { i := add(i, 1) } {
                // @audit mitigation Done
                // copy from transient storage into memory
                mstore(add(swapData, mul(i, 0x20)), tload(add(i, 3)))
            }
            // update the free memory pointer
            mstore(0x40, add(swapData, add(swapDataSize, 0x20))) // @audit mitigation Done
            newFMP := mload(0x40)
        }

        return (oldFMP, newFMP, swapData);
    }
}

contract EntryPoint {
    address public transit;

    constructor(address _transit) {
        transit = _transit;
    }

    function testAtomicSwap(bytes calldata swapData) external returns (uint256, bytes memory) {
        Transit(transit).storeVariables(0x5, address(0xff), 0x1000, address(0xbb), 0x5000, swapData);

        (uint256 oldFMP, uint256 newFMP, bytes memory returnedSwapData) = Transit(transit).loadVariables();

        require(newFMP > oldFMP, "newFMP is smalelr than oldFMP");

        return (newFMP - oldFMP, returnedSwapData);
    }
}

contract AtomicSwapExtensionTest is Test {
    EntryPoint entryPoint;

    function setUp() public {
        address __transit = address(new Transit());
        entryPoint = new EntryPoint(__transit);
    }

    function testMemoryManagmentFuzzing(uint256 number) public {
        uint256[] memory array = new uint256[]((number % 100) + 1);

        for (uint256 i = 0; i < array.length; i++) {
            array[i] = type(uint256).max;
        }

        bytes4 functionSignature = bytes4(0x11223344);

        bytes memory swapData = abi.encodePacked(functionSignature, array);
        uint256 callEncodeLength = swapData.length /* func signature + data */ + 0x20; /* The length offset */
        (uint256 memoryAllocated, bytes memory returnedSwapData) = entryPoint.testAtomicSwap(swapData);
        assertEq(callEncodeLength, memoryAllocated);
        assertEq(keccak256(returnedSwapData), keccak256(swapData));
    }
}
