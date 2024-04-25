// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";

import {BaseTestV2}          from "./BaseV2.sol";
import {Licenser}            from "../../src/core/Licenser.sol";
import {IVaultManager}       from "../../src/interfaces/IVaultManager.sol";
import {IVault}              from "../../src/interfaces/IVault.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";

/**
Notes: Fork test 
  - block 19621640
  - $3,545.56 / ETH
*/

contract V2Test is BaseTestV2 {

  function test_LicenseVaultManager() public {
    Licenser licenser = Licenser(MAINNET_VAULT_MANAGER_LICENSER);
    vm.prank(MAINNET_OWNER);
    licenser.add(address(contracts.vaultManager));
  }

  function test_LicenseVaults() public {
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.ethVault), false);
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.wstEth), false);
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.unboundedKerosineVault), true);
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.boundedKerosineVault), true);
  }

  function test_KeroseneVaults() public {
    address[] memory vaults = contracts.kerosineManager.getVaults();
    assertEq(vaults.length, 2);
    assertEq(vaults[0], address(contracts.ethVault));
    assertEq(vaults[1], address(contracts.wstEth));
  }

  function test_Ownership() public {
    assertEq(contracts.kerosineManager.owner(),        MAINNET_OWNER);
    assertEq(contracts.vaultLicenser.owner(),          MAINNET_OWNER);
    assertEq(contracts.kerosineManager.owner(),        MAINNET_OWNER);
    assertEq(contracts.unboundedKerosineVault.owner(), MAINNET_OWNER);
    assertEq(contracts.boundedKerosineVault.owner(),   MAINNET_OWNER);
  }

  function test_Denominator() public {
    uint denominator = contracts.kerosineDenominator.denominator();
    assertTrue(denominator < contracts.kerosene.balanceOf(MAINNET_OWNER));
  }

  function test_MintDNftOwner0() 
    public 
      mintAlice0 
  {
    assertEq(contracts.dNft.balanceOf(alice), 1);
  }

  function test_MintDNftOwner1() 
    public 
      mintBob0 
  {
    assertEq(contracts.dNft.balanceOf(bob), 1);
  }

  function test_Mint2DNfts() 
    public 
      mintAlice0 
      mintAlice1 
  {
    assertEq(contracts.dNft.balanceOf(alice), 2);
  }

  modifier addVault(uint id, IVault vault) {
    vm.prank(contracts.dNft.ownerOf(id));
    contracts.vaultManager.add(id, address(vault));
    _;
  }

  function test_AddVault() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault) 
  {
    address firstVault = contracts.vaultManager.getVaults(alice0)[0];
    assertEq(firstVault, address(contracts.ethVault));
  }

  function test_Add2Vaults() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault) 
      addVault(alice0, contracts.wstEth)
  {
    address[] memory vaults = contracts.vaultManager.getVaults(alice0);
    assertEq(vaults[0], address(contracts.ethVault));
    assertEq(vaults[1], address(contracts.wstEth));
  }

  modifier deposit(uint id, IVault vault, uint amount) {
    address owner = contracts.dNft.ownerOf(id);
    vm.startPrank(owner);

    ERC20 asset = vault.asset();
    deal(address(asset), owner, amount);
    asset.approve(address(contracts.vaultManager), amount);
    contracts.vaultManager.deposit(id, address(vault), amount);

    vm.stopPrank();
    _;
  }

  function test_Deposit() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 100 ether)
  {
    assertEq(contracts.ethVault.id2asset(alice0), 100 ether);
  }

  function test_DepositBob() 
    public 
      mintBob0 
      addVault(bob0, contracts.ethVault)
      deposit (bob0, contracts.ethVault, 100 ether)
  {
    assertEq(contracts.ethVault.id2asset(bob0), 100 ether);
  }

  modifier burnDyad(uint id, uint amount) {
    contracts.vaultManager.burnDyad(id, amount);
    _;
  }

  function test_BurnAllDyad() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 100 ether)
      mintDyad(alice0, _ethToUSD(10 ether))
      burnDyad(alice0, _ethToUSD(10 ether))
  {
    assertEq(getMintedDyad(alice0), 0);
    assertEq(contracts.dyad.balanceOf(address(this)), 0);
  }

  function test_BurnSomeDyad() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 100 ether)
      mintDyad(alice0, _ethToUSD(10 ether))
      burnDyad(alice0, _ethToUSD(1 ether))
  {
    assertEq(getMintedDyad(alice0), _ethToUSD(10 ether - 1 ether));
  }

  function test_BurnSomeDyadAndMintSomeDyad() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 100 ether)
      mintDyad(alice0, _ethToUSD(10 ether))
      burnDyad(alice0, _ethToUSD(1 ether))
      mintDyad(alice0, _ethToUSD(1 ether))
  {
    assertEq(getMintedDyad(alice0), _ethToUSD(
      10 ether - 1 ether + 1 ether
    ));
  }

  modifier redeemDyad(uint id, IVault vault, uint amount) {
    contracts.vaultManager.redeemDyad(
      id,
      address(vault),
      amount,
      address(this)
    );
    _;
  }

  function test_RedeemDyad() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 100 ether)
      mintDyad(alice0, _ethToUSD(10 ether))
      skipBlock(1)
      redeemDyad(alice0, contracts.ethVault, _ethToUSD(10 ether))
  {
    assertTrue(contracts.ethVault.id2asset(alice0) < 100 ether);
  }

  modifier withdraw(IVault vault, uint amount) {
    contracts.vaultManager.withdraw(
      alice0,
      address(vault),
      amount,
      address(this)
    );
    _;
  }

  /// @dev All collateral can be withdrawn if no DYAD was minted
  function test_WithdrawEverythingWithoutMintingDyad() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 100 ether)
      skipBlock(1)
      withdraw(contracts.ethVault, 100 ether)
  {
    assertEq(contracts.ethVault.id2asset(alice0), 0 ether);
  }

  function test_WithdrawSomeEthAfterMintingDyad() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 100 ether)
      skipBlock(1)
      mintDyad(alice0, _ethToUSD(2 ether)) 
      skipBlock(1)
      withdraw(contracts.ethVault, 22 ether)
  {
    assertEq(contracts.ethVault.id2asset(alice0), 100 ether - 22 ether);
  }

  /// @dev Test fails because the withdarwl of 1 Ether will put it under the CR
  ///      limit.
  function test_FailWithdrawCrTooLow() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 10 ether)
      skipBlock(1) // is not actually needed
      mintDyad(alice0, _ethToUSD(6.55 ether)) 
      skipBlock(1)
      nextCallFails(IVaultManager.CrTooLow.selector)
      withdraw(contracts.ethVault, 1 ether)
  {}

  function test_FailWithdrawNotEnoughExoCollateral() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 10 ether)
      skipBlock(1) // is not actually needed
      mintDyad(alice0, _ethToUSD(6.55 ether)) 
      skipBlock(1)
      nextCallFails(IVaultManager.NotEnoughExoCollat.selector)
      withdraw(contracts.ethVault, 5 ether)
  {}

  /// @dev Test fails because deposit and withdraw are in the same block
  ///      which is forbidden to prevent flash loan attacks.
  function test_FailDepositAndWithdrawInSameBlock() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 100 ether)
      // skipBlock(1)
      nextCallFails(IVaultManager.CanNotWithdrawInSameBlock.selector)
      withdraw(contracts.ethVault, 100 ether)
  {}

  modifier mintDyad(uint id, uint amount) {
    vm.prank(contracts.dNft.ownerOf(id));
    contracts.vaultManager.mintDyad(id, amount, address(this));
    _;
  }

  function test_MintDyad() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit(alice0, contracts.ethVault, 100 ether)
      mintDyad(alice0, 1e18)
  {
    assertEq(contracts.dyad.balanceOf(address(this)), 1e18);
  }

  function test_CollatRatio() 
    public 
      mintAlice0 
  {
    /// @dev Before minting DYAD every DNft has the highest possible CR which 
    ///      is equal to type(uint).max 
    assertTrue(contracts.vaultManager.collatRatio(alice0) == type(uint).max);
  }

  function test_CollatRatioAfterMinting() 
    public 
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit (alice0, contracts.ethVault, 100 ether)
      mintDyad(alice0, _ethToUSD(1 ether))
  {
    /// @dev Before minting DYAD every DNft has the highest possible CR which 
    ///      is equal to type(uint).max. After minting DYAD the CR should be
    ///      less than that.
    assertTrue(contracts.vaultManager.collatRatio(alice0) < type(uint).max);
  }

  function test_Liquidate() 
    public 
      // Alice Position
      mintAlice0 
      addVault(alice0, contracts.ethVault)
      deposit (alice0, contracts.ethVault, 100 ether)
      mintDyad(alice0, _ethToUSD(1 ether))
      // Bob Position
      mintBob0 
      addVault(bob0, contracts.ethVault)
      deposit (bob0, contracts.ethVault, 100 ether)
      mintDyad(bob0, _ethToUSD(50 ether))
  {
    uint oldPrice = contracts.ethVault.getUsdValue(alice0);
    console.log("oldPrice", oldPrice);

    vm.rollFork(19721640);

    uint newPrice = contracts.ethVault.getUsdValue(alice0);
    console.log("newPrice", newPrice);

    // assertEq(contracts.dyad.balanceOf(address(this)), 1e18);
  }
}
