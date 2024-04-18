// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseTestV2}          from "./BaseV2.sol";
import {Licenser}            from "../../src/core/Licenser.sol";
import {IVaultManager}       from "../../src/interfaces/IVaultManager.sol";
import {IVault}              from "../../src/interfaces/IVault.sol";

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

  modifier mintDNft() {
    uint startPrice    = contracts.dNft.START_PRICE();
    uint priceIncrease = contracts.dNft.PRICE_INCREASE();
    uint publicMints   = contracts.dNft.publicMints();
    uint price = startPrice + (priceIncrease * publicMints);
    vm.deal(address(this), price);
    uint id = contracts.dNft.mintNft{value: price}(address(this));
    DNFT_ID_1 = id;
    _;
  }

  function test_MintDNft() public mintDNft {
    assertEq(contracts.dNft.balanceOf(address(this)), 1);
  }

  modifier addVault(IVault vault) {
    contracts.vaultManager.add(DNFT_ID_1, address(vault));
    _;
  }

  function test_AddVault() 
    public 
      mintDNft 
      addVault(contracts.ethVault) 
  {
    address firstVault = contracts.vaultManager.getVaults(DNFT_ID_1)[0];
    assertEq(firstVault, address(contracts.ethVault));
  }

  modifier deposit(IVault vault, uint amount) {
    deal(MAINNET_WETH, address(this), amount);
    weth.approve(address(contracts.vaultManager), amount);
    contracts.vaultManager.deposit(DNFT_ID_1, address(vault), amount);
    _;
  }

  function test_Deposit() 
    public 
      mintDNft 
      addVault(contracts.ethVault)
      deposit(contracts.ethVault, 100 ether)
  {
    assertEq(contracts.ethVault.id2asset(DNFT_ID_1), 100 ether);
  }

  modifier withdraw(IVault vault, uint amount) {
    contracts.vaultManager.withdraw(
      DNFT_ID_1,
      address(vault),
      amount,
      address(this)
    );
    _;
  }

  function test_Withdraw() 
    public 
      mintDNft 
      addVault(contracts.ethVault)
      deposit(contracts.ethVault, 100 ether)
      skipBlock(1)
      withdraw(contracts.ethVault, 100 ether)
  {
    assertEq(contracts.ethVault.id2asset(DNFT_ID_1), 0 ether);
  }

  /// @dev Test fails because deposit and withdraw are in the same block
  ///      which is forbidden to prevent flash loan attacks.
  function test_FailDepositAndWithdrawInSameBlock() 
    public 
      mintDNft 
      addVault(contracts.ethVault)
      deposit(contracts.ethVault, 100 ether)
      // skipBlock(1)
      nextCallFails(IVaultManager.DepositedInSameBlock.selector)
      withdraw(contracts.ethVault, 100 ether)
  {}

  modifier mintDyad(uint amount) {
    contracts.vaultManager.mintDyad(DNFT_ID_1, amount, address(this));
    _;
  }

  function test_MintDyad() 
    public 
      mintDNft 
      addVault(contracts.ethVault)
      deposit(contracts.ethVault, 100 ether)
      mintDyad(1e18)
  {
    assertEq(contracts.dyad.balanceOf(address(this)), 1e18);

    /// @dev Before minting DYAD every DNft has the highest possible CR which 
    ///      is equal to type(uint).max. After minting DYAD the CR should be
    ///      less than that.
    assertTrue(contracts.vaultManager.collatRatio(DNFT_ID_1) < type(uint).max);
  }
}
