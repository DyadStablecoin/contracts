// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {DNft} from "../src/core/DNft.sol";
import {Parameters} from "../src/params/Parameters.sol";
import {VaultApxETH} from "../src/core/Vault.apxETH.sol";
import {VaultManager} from "../src/core/VaultManager.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {IAggregatorV3} from "../src/interfaces/IAggregatorV3.sol";
import {IVault} from "../src/interfaces/IVault.sol";

contract VaultApxETHTest is Test, Parameters {
    VaultApxETH vault;

    uint256 depositCap = 100 ether;

    function setUp() public {
        vault = new VaultApxETH(
            address(MAINNET_FEE_RECIPIENT), // owner
            VaultManager(MAINNET_V2_VAULT_MANAGER),
            ERC20(MAINNET_APXETH),
            IAggregatorV3(MAINNET_APXETH_ORACLE),
            IVault(MAINNET_V2_WETH_VAULT),
            DNft(MAINNET_DNFT)
        );

        vm.prank(MAINNET_FEE_RECIPIENT);
        vault.setDepositCap(depositCap);
    }

    function test_assetPrice() public view {
        uint256 price = vault.assetPrice();
        console.log("price: %s", price);
    }

    function testFuzz_setDepositCapReverts(address sender) public {
        vm.assume(sender != address(MAINNET_FEE_RECIPIENT));
        uint256 cap = 1000e18;
        vm.prank(sender);
        vm.expectRevert("UNAUTHORIZED");
        vault.setDepositCap(cap);
    }

    function testFuzz_setDepositCapAsOwner(uint256 cap) public {
        vm.prank(MAINNET_FEE_RECIPIENT);
        vault.setDepositCap(cap);
        uint256 newCap = vault.depositCap();
        assertEq(newCap, cap);
    }

    function testFuzzDepositCap(
        uint256 currentDeposit,
        uint256 depositAmount
    ) public {
        vm.assume(depositAmount < type(uint128).max);
        vm.assume(currentDeposit < depositCap);

        vm.mockCall(
            MAINNET_APXETH,
            abi.encodeWithSignature("balanceOf(address)", address(vault)),
            abi.encode(currentDeposit + depositAmount)
        );

        vm.prank(MAINNET_V2_VAULT_MANAGER);
        if (currentDeposit + depositAmount > depositCap) {
            vm.expectRevert(VaultApxETH.ExceedsDepositCap.selector);
        }
        vault.deposit(1, depositAmount);
    }
}
