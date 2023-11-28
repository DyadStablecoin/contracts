// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import {VaultManagerTestHelper} from "./VaultManagerHelper.t.sol";
import {IVaultManager} from "../src/interfaces/IVaultManager.sol";

contract VaultManagerTest is VaultManagerTestHelper {
    ///////////////////////////
    // add
    function test_add() public {
        uint256 id = mintDNft();
        vaultManager.add(id, address(wethVault));
        assertEq(vaultManager.vaults(id, 0), address(wethVault));
    }

    function test_addTwoVaults() public {
        uint256 id = mintDNft();
        addVault(id, RANDOM_VAULT_1);
        addVault(id, RANDOM_VAULT_2);
        assertEq(vaultManager.isDNftVault(id, RANDOM_VAULT_1), true);
        assertEq(vaultManager.isDNftVault(id, RANDOM_VAULT_2), true);
        assertEq(vaultManager.vaults(id, 0), RANDOM_VAULT_1);
        assertEq(vaultManager.vaults(id, 1), RANDOM_VAULT_2);
        vm.expectRevert();
        vaultManager.vaults(id, 2); // out of bounds
    }

    function testCannot_add_exceptForDNftOwner() public {
        uint256 id = mintDNft();
        vm.prank(address(1));
        vm.expectRevert(IVaultManager.NotOwner.selector);
        vaultManager.add(id, address(wethVault));
    }

    function testFail_add_moreThanMaxNumberOfVaults() public {
        uint256 id = mintDNft();

        for (uint256 i = 0; i < vaultManager.MAX_VAULTS(); i++) {
            addVault(id, address(uint160(i)));
        }
        // this puts it exactly one over the limit and should fail
        addVault(id, RANDOM_VAULT_1);
    }

    function testCannot_add_unlicensedVault() public {
        uint256 id = mintDNft();
        vm.expectRevert(IVaultManager.VaultNotLicensed.selector);
        vaultManager.add(id, RANDOM_VAULT_1);
    }

    function testFail_cannotAddSameVaultTwice() public {
        uint256 id = mintDNft();
        addVault(id, RANDOM_VAULT_1);
        addVault(id, RANDOM_VAULT_1);
    }

    ///////////////////////////
    // remove
    function test_remove() public {
        uint256 id = mintDNft();
        vaultManager.add(id, address(wethVault));
        vaultManager.remove(id, address(wethVault));
    }

    function testCannot_remove_exceptForDNftOwner() public {
        uint256 id = mintDNft();
        vaultManager.add(id, address(wethVault));
        vm.prank(address(1));
        vm.expectRevert(IVaultManager.NotOwner.selector);
        vaultManager.remove(id, address(wethVault));
    }

    ///////////////////////////
    // deposit
    function test_deposit() public {
        uint256 id = mintDNft();
        uint256 AMOUNT = 1e18;
        deposit(weth, id, address(wethVault), AMOUNT);
        assertEq(wethVault.id2asset(id), AMOUNT);
    }

    function test_depositMultipleCollateralTypes() public {
        uint256 id = mintDNft();

        uint256 WETH_AMOUNT = 1e18;
        deposit(weth, id, address(wethVault), WETH_AMOUNT);
        assertEq(wethVault.id2asset(id), WETH_AMOUNT);

        uint256 DAI_AMOUNT = 22e16;
        deposit(dai, id, address(daiVault), DAI_AMOUNT);
        assertEq(daiVault.id2asset(id), DAI_AMOUNT);
    }

    ///////////////////////////
    // withdraw
    function test_withdraw() public {
        uint256 id = mintDNft();
        deposit(weth, id, address(wethVault), 1e18);
        vaultManager.withdraw(id, address(wethVault), 1e18, RECEIVER);
    }

    ///////////////////////////
    // mintDyad
    function test_mintDyad() public {
        uint256 id = mintDNft();
        deposit(weth, id, address(wethVault), 1e22);
        vaultManager.mintDyad(id, 1e20, RECEIVER);
    }

    ///////////////////////////
    // burnDyad
    function test_burnDyad() public {
        uint256 id = mintDNft();
        deposit(weth, id, address(wethVault), 1e22);
        vaultManager.mintDyad(id, 1e20, address(this));
        vaultManager.burnDyad(id, 1e20);
    }

    ///////////////////////////
    // redeemDyad
    function test_redeemDyad() public {
        uint256 id = mintDNft();
        deposit(weth, id, address(wethVault), 1e22);
        vaultManager.mintDyad(id, 1e20, address(this));
        vaultManager.redeemDyad(id, address(wethVault), 1e20, RECEIVER);
    }

    ///////////////////////////
    // collatRatio
    function test_collatRatio() public {
        uint256 id = mintDNft();
        uint256 cr = vaultManager.collatRatio(id);
        assertEq(cr, type(uint256).max);
        deposit(weth, id, address(wethVault), 1e22);
        vaultManager.mintDyad(id, 1e24, address(this));
        cr = vaultManager.collatRatio(id);
        assertEq(cr, 10000000000000000000);
    }

    ///////////////////////////
    // getTotalUsdValue
    function test_getTotalUsdValue() public {
        uint256 id = mintDNft();
        uint256 DEPOSIT = 1e22;
        deposit(weth, id, address(wethVault), DEPOSIT);
        uint256 usdValue = vaultManager.getTotalUsdValue(id);
        assertEq(usdValue, 10000000000000000000000000);

        deposit(dai, id, address(daiVault), DEPOSIT);
        usdValue = vaultManager.getTotalUsdValue(id);
        assertEq(usdValue, 10000100000000000000000000);
    }
}
