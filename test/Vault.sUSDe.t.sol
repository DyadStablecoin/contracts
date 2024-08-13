// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {DNft} from "../src/core/DNft.sol";
import {Parameters} from "../src/params/Parameters.sol";
import {VaultStakedUSDe} from "../src/core/Vault.sUSDe.sol";
import {VaultManager} from "../src/core/VaultManager.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {IAggregatorV3} from "../src/interfaces/IAggregatorV3.sol";
import {IWstETH} from "../src/interfaces/IWstETH.sol";

contract VaultStakedUSDeTest is Test, Parameters {
    VaultStakedUSDe vault;

    function setUp() public {
        vault = new VaultStakedUSDe(
            address(this), // owner
            VaultManager(MAINNET_V2_VAULT_MANAGER),
            ERC20(MAINNET_WSTETH),
            IAggregatorV3(MAINNET_CHAINLINK_SUSDE),
            DNft(MAINNET_DNFT)
        );
    }

    function test_assetPrice() public view {
        uint256 price = vault.assetPrice();
        console.log("price: %s", price);
    }

    function testFuzz_setDepositCapReverts(address sender) public {
        vm.assume(sender != address(this));
        uint256 cap = 1000e18;
        vm.prank(sender);
        vm.expectRevert("UNAUTHORIZED");
        vault.setDepositCap(cap);
    }

    function testFuzz_setDepositCapAsOwner(uint256 cap) public {
        vault.setDepositCap(cap);
        uint256 newCap = vault.depositCap();
        assertEq(newCap, cap);
    }

    function testFuzz_depositOverCapReverts(
        uint256 cap,
        uint256 depositAmount
    ) public {
        vm.assume(depositAmount > cap);
        vault.setDepositCap(cap);
        vm.prank(MAINNET_V2_VAULT_MANAGER);
        vm.expectRevert(VaultStakedUSDe.ExceedsDepositCap.selector);
        vault.deposit(1, depositAmount);
    }
}
