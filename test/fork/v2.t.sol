// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";

import {BaseTestV2}          from "./BaseV2.sol";
import {Licenser}            from "../../src/core/Licenser.sol";
import {IVaultManager}       from "../../src/interfaces/IVaultManager.sol";
import {IVault}              from "../../src/interfaces/IVault.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract V2Test is BaseTestV2 {

  function test_LicenseVaultManager() public {
    Licenser licenser = Licenser(MAINNET_VAULT_MANAGER_LICENSER);
    vm.prank(MAINNET_OWNER);
    licenser.add(address(contracts.vaultManager));
  }

  function test_LicenseVaults() public {
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.ethVault));
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.wstEth));
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.unboundedKerosineVault));
    vm.prank(MAINNET_OWNER);
    contracts.vaultLicenser.add(address(contracts.boundedKerosineVault));
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

  function mintDNft() public returns(uint id) {
    uint startPrice    = contracts.dNft.START_PRICE();
    uint priceIncrease = contracts.dNft.PRICE_INCREASE();
    uint publicMints   = contracts.dNft.publicMints();
    uint price = startPrice + (priceIncrease * publicMints);
    vm.deal(address(this), price);
    id = contracts.dNft.mintNft{value: price}(address(this));
  }

  modifier mintDNft0() { DNFT_ID_0 = mintDNft(); _; }
  modifier mintDNft1() { DNFT_ID_1 = mintDNft(); _; }

  function test_MintDNft() 
    public 
      mintDNft0 
  {
    assertEq(contracts.dNft.balanceOf(address(this)), 1);
  }

  function test_Mint2DNfts() 
    public 
      mintDNft0 
      mintDNft1 
  {
    assertEq(contracts.dNft.balanceOf(address(this)), 2);
  }

  modifier addVault(IVault vault) {
    contracts.vaultManager.add(DNFT_ID_0, address(vault));
    _;
  }

  function test_AddVault() 
    public 
      mintDNft0 
      addVault(contracts.ethVault) 
  {
    address firstVault = contracts.vaultManager.getVaults(DNFT_ID_0)[0];
    assertEq(firstVault, address(contracts.ethVault));
  }

  function test_Add2Vaults() 
    public 
      mintDNft0 
      addVault(contracts.ethVault) 
      addVault(contracts.wstEth)
  {
    address[] memory vaults = contracts.vaultManager.getVaults(DNFT_ID_0);
    assertEq(vaults[0], address(contracts.ethVault));
    assertEq(vaults[1], address(contracts.wstEth));
  }

  modifier deposit(IVault vault, uint amount) {
    ERC20 asset = vault.asset();
    deal(address(asset), address(this), amount);
    asset.approve(address(contracts.vaultManager), amount);
    contracts.vaultManager.deposit(DNFT_ID_0, address(vault), amount);
    _;
  }

  function test_Deposit() 
    public 
      mintDNft0 
      addVault(contracts.ethVault)
      deposit(contracts.ethVault, 100 ether)
  {
    assertEq(contracts.ethVault.id2asset(DNFT_ID_0), 100 ether);
  }

  modifier withdraw(IVault vault, uint amount) {
    contracts.vaultManager.withdraw(
      DNFT_ID_0,
      address(vault),
      amount,
      address(this)
    );
    _;
  }

  function test_Withdraw() 
    public 
      mintDNft0 
      addVault(contracts.ethVault)
      deposit(contracts.ethVault, 100 ether)
      skipBlock(1)
      withdraw(contracts.ethVault, 100 ether)
  {
    assertEq(contracts.ethVault.id2asset(DNFT_ID_0), 0 ether);
  }

  /// @dev Test fails because deposit and withdraw are in the same block
  ///      which is forbidden to prevent flash loan attacks.
  function test_FailDepositAndWithdrawInSameBlock() 
    public 
      mintDNft0 
      addVault(contracts.ethVault)
      deposit(contracts.ethVault, 100 ether)
      // skipBlock(1)
      nextCallFails(IVaultManager.DepositedInSameBlock.selector)
      withdraw(contracts.ethVault, 100 ether)
  {}

  modifier mintDyad(uint amount) {
    contracts.vaultManager.mintDyad(DNFT_ID_0, amount, address(this));
    _;
  }

  function test_MintDyad() 
    public 
      mintDNft0 
      addVault(contracts.ethVault)
      deposit(contracts.ethVault, 100 ether)
      mintDyad(1e18)
  {
    assertEq(contracts.dyad.balanceOf(address(this)), 1e18);
  }

  function test_CollatRatio() 
    public 
      mintDNft0 
  {
    /// @dev Before minting DYAD every DNft has the highest possible CR which 
    ///      is equal to type(uint).max 
    assertTrue(contracts.vaultManager.collatRatio(DNFT_ID_0) == type(uint).max);
  }

  function test_CollatRatioAfterMinting() 
    public 
      mintDNft0 
      addVault(contracts.ethVault)
      deposit(contracts.ethVault, 100 ether)
      mintDyad(1e18)
  {
    /// @dev Before minting DYAD every DNft has the highest possible CR which 
    ///      is equal to type(uint).max. After minting DYAD the CR should be
    ///      less than that.
    assertTrue(contracts.vaultManager.collatRatio(DNFT_ID_0) < type(uint).max);
  }

  modifier addVaultKerosene(IVault vault) {
    contracts.vaultManager.addKerosene(DNFT_ID_0, address(vault));
    _;
  }

  function test_AddVaultKerosene() 
    public 
      mintDNft0 
      addVaultKerosene(contracts.unboundedKerosineVault) 
  {
    address firstVault = contracts.vaultManager.getVaultsKerosene(DNFT_ID_0)[0];
    assertEq(firstVault, address(contracts.unboundedKerosineVault));
  }

  function test_DepositKerosene() 
    public 
      mintDNft0 
      addVaultKerosene(contracts.unboundedKerosineVault) 
      deposit(contracts.unboundedKerosineVault, 100e18)
  {
    assertEq(contracts.unboundedKerosineVault.id2asset(DNFT_ID_0), 100e18);
  }

  function test_KerosenePrice() 
    public 
      mintDNft0 
      addVault(contracts.ethVault)
      deposit(contracts.ethVault, 300 ether)
  {
    uint price = contracts.unboundedKerosineVault.assetPrice();
    assertTrue(price > 0);
  }
}
