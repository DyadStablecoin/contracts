// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Parameters} from "../src/params/Parameters.sol";
import {VaultWeETH} from "../src/core/Vault.weETH.sol";
import {VaultManager} from "../src/core/VaultManager.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {IAggregatorV3} from "../src/interfaces/IAggregatorV3.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {DNft} from "../src/core/DNft.sol";

contract VaultWeETHTest is Test, Parameters {
    VaultWeETH vault;

    uint256 depositCap = 100 ether;

    function setUp() public {
        vault = new VaultWeETH(
            MAINNET_FEE_RECIPIENT,
            VaultManager(MAINNET_V2_VAULT_MANAGER),
            // use WETH for test so we can simulate deposit
            ERC20(MAINNET_WEETH),
            IAggregatorV3(MAINNET_CHAINLINK_WEETH),
            IVault(MAINNET_V2_WETH_VAULT),
            DNft(MAINNET_DNFT)
        );

        vm.prank(MAINNET_FEE_RECIPIENT);
        vault.setDepositCap(depositCap);
    }

    function test_assetPrice() public {
        uint256 price = vault.assetPrice();
        console.log("price: %s", price);
    }

    function test_usdValue() public {
        vm.prank(MAINNET_V2_VAULT_MANAGER);
        vault.deposit(1, 2.21 ether);
        uint256 usdValue = vault.getUsdValue(1);
        console.log("usdValue: %s", usdValue);
    }

    function testFuzzDepositCap(
        uint256 currentDeposit,
        uint256 depositAmount
    ) public {
        vm.assume(depositAmount < type(uint128).max);
        vm.assume(currentDeposit < depositCap);

        vm.mockCall(
            MAINNET_WEETH,
            abi.encodeWithSignature("balanceOf(address)", address(vault)),
            abi.encode(currentDeposit)
        );

        vm.prank(MAINNET_V2_VAULT_MANAGER);
        if (currentDeposit + depositAmount > depositCap) {
            vm.expectRevert(VaultWeETH.ExceedsDepositCap.selector);
        }
        vault.deposit(1, depositAmount);
    }
}
