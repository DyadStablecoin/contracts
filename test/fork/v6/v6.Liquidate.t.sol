// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {BaseTestV6} from "./BaseV6.sol";
import {VaultManagerV3} from "../../../src/core/VaultManagerV3.sol";
import {Parameters} from "../../../src/params/Parameters.sol";
import {DeployVaultManagerV3} from "../../../script/deploy/DeployVaultManagerV3.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IVault} from "../../../src/interfaces/IVault.sol";

contract LiquidateTest is BaseTestV6 {
    modifier mintDyad(uint256 id, uint256 amount) {
        vm.prank(contracts.dNft.ownerOf(id));
        contracts.vaultManager.mintDyad(id, amount, address(this));
        _;
    }

    modifier liquidate(uint256 id, uint256 to, address liquidator) {
        deal(address(contracts.dyad), liquidator, _ethToUSD(getMintedDyad(id)));
        vm.prank(liquidator);
        contracts.vaultManager.liquidate(id, to, getMintedDyad(id));
        _;
    }

    function test_LiquidateWithManyVaults()
        public
        // alice
        mintAlice0
        // eth vault
        addVault(alice0, contracts.ethVault)
        deposit(alice0, contracts.ethVault, 100 ether)
        // wstEth vault
        addVault(alice0, contracts.wstEth)
        deposit(alice0, contracts.wstEth, 100 ether)
        // kerosene vault
        addVault(alice0, contracts.keroseneVault)
        deposit(alice0, contracts.keroseneVault, 5 ether)
        mintDyad(alice0, _ethToUSD(10 ether))
        // change assets
        changeAsset(alice0, contracts.ethVault, 1 ether)
        changeAsset(alice0, contracts.wstEth, 1 ether)
        changeAsset(alice0, contracts.keroseneVault, 1 ether)
        // bob
        mintBob0
        liquidate(alice0, bob0, bob)
    {}

    function testFuzz_LiquidateWithManyVaults(uint256 amount)
        public
        // alice
        mintAlice0
        // eth vault
        addVault(alice0, contracts.ethVault)
        deposit(alice0, contracts.ethVault, 100 ether)
        // wstEth vault
        addVault(alice0, contracts.wstEth)
        deposit(alice0, contracts.wstEth, 100 ether)
        // kerosene vault
        addVault(alice0, contracts.keroseneVault)
        deposit(alice0, contracts.keroseneVault, 5 ether)
        mintDyad(alice0, _ethToUSD(10 ether))
        // change assets
        changeAsset(alice0, contracts.ethVault, 1 ether)
        changeAsset(alice0, contracts.wstEth, 1 ether)
        changeAsset(alice0, contracts.keroseneVault, 1 ether)
        // bob
        mintBob0
    {
        amount = bound(amount, 1, _ethToUSD(10 ether));
        contracts.vaultManager.liquidate(alice0, bob0, amount);
    }

    function test_LiquidateNoCollateralLeftForLiquidatee()
        public
        // alice
        mintAlice0
        addVault(alice0, contracts.ethVault)
        deposit(alice0, contracts.ethVault, 100 ether)
        mintDyad(alice0, _ethToUSD(1 ether))
        changeAsset(alice0, contracts.ethVault, 1.2 ether)
        // bob
        mintBob0
        liquidate(alice0, bob0, bob)
    {
        uint256 ethAfter_Liquidator = contracts.ethVault.id2asset(bob0);
        uint256 ethAfter_Liquidatee = contracts.ethVault.id2asset(alice0);
        uint256 dyadAfter_Liquidatee = contracts.dyad.mintedDyad(alice0);

        assertGt(ethAfter_Liquidator, 0);
        assertEq(ethAfter_Liquidatee, 0);

        assertEq(getMintedDyad(alice0), 0);
        assertEq(getCR(alice0), type(uint256).max);
        assertEq(dyadAfter_Liquidatee, 0);
    }

    function test_LiquidateSomeCollateralLeft()
        public
        // alice
        mintAlice0
        addVault(alice0, contracts.ethVault)
        deposit(alice0, contracts.ethVault, 100 ether)
        mintDyad(alice0, _ethToUSD(1 ether))
        changeAsset(alice0, contracts.ethVault, 1.4 ether)
        // bob
        mintBob0
        liquidate(alice0, bob0, bob)
    {
        uint256 ethAfter_Liquidator = contracts.ethVault.id2asset(bob0);
        uint256 ethAfter_Liquidatee = contracts.ethVault.id2asset(alice0);
        uint256 dyadAfter_Liquidatee = contracts.dyad.mintedDyad(alice0);

        assertGt(ethAfter_Liquidator, 0);
        assertGt(ethAfter_Liquidatee, 0);

        assertEq(getMintedDyad(alice0), 0);
        assertEq(getCR(alice0), type(uint256).max);
        assertEq(dyadAfter_Liquidatee, 0);
    }

    function test_LiquidatePartial()
        public
        // alice
        mintAlice0
        addVault(alice0, contracts.ethVault)
        deposit(alice0, contracts.ethVault, 100 ether)
        addVault(alice0, contracts.wstEth)
        deposit(alice0, contracts.wstEth, 100 ether)
        mintDyad(alice0, _ethToUSD(50 ether))
        changeAsset(alice0, contracts.ethVault, 50 ether)
        changeAsset(alice0, contracts.wstEth, 10 ether)
        // bob
        mintBob0
    {
        uint256 crBefore = getCR(alice0);
        console.log("crBefore: ", crBefore / 1e15);

        uint256 debtBefore = getMintedDyad(alice0);
        console.log("debtBefore: ", debtBefore / 1e18);

        contracts.vaultManager.liquidate(alice0, bob0, _ethToUSD(10 ether));

        uint256 crAfter = getCR(alice0);
        console.log("crAfter: ", crAfter / 1e15);

        uint256 debtAfter = getMintedDyad(alice0);
        console.log("debtAfter: ", debtAfter / 1e18);
    }

    function test_LiquidateFromV5() public {
        IVault keroseneVault = IVault(MAINNET_V2_KEROSENE_V2_VAULT);
        IVault apxVault = IVault(MAINNET_APXETH_VAULT);

        uint256 keroBefore = keroseneVault.id2asset(511);
        uint256 apxBefore = apxVault.id2asset(511);

        console.log("debt before: ", contracts.dyad.mintedDyad(511));

        vm.prank(0xBA1aAd8B27e841C8E3298e4ceadB0524b4d4B978);
        (address[] memory vaults, uint256[] memory amounts) =
            contracts.vaultManager.liquidate(511, 108, 3_238_833_231_264_062_800_000); // $3238 dyad
        vm.assertEq(4, vaults.length);

        console.log("debt after: ", contracts.dyad.mintedDyad(511));

        vm.assertEq(vaults[2], MAINNET_V2_KEROSENE_V2_VAULT);
        vm.assertLt(amounts[2], 9643113711581927460479);

        vm.assertEq(vaults[3], MAINNET_APXETH_VAULT);
        vm.assertGt(amounts[3], 1029566515236775113);

        uint256 keroAfter = keroseneVault.id2asset(511);
        uint256 apxAfter = apxVault.id2asset(511);

        console.log("keroBefore: ", keroBefore);
        console.log("apxBefore: ", apxBefore);
        console.log("keroAfter: ", keroAfter);
        console.log("apxAfter: ", apxAfter);

        console.log("keroLoss: ", keroBefore - keroAfter);
        console.log("apxLoss: ", apxBefore - apxAfter);

        console.log("apxPrice: ", apxVault.assetPrice());
    }
}
