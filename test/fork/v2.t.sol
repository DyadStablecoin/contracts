// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import {DeployV2, Contracts} from "../../script/deploy/Deploy.V2.s.sol";
import {Licenser} from "../../src/core/Licenser.sol";
import {Parameters} from "../../src/params/Parameters.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract V2Test is Test, Parameters {

  Contracts contracts;
  ERC20 weth;

  uint DNFT_ID_1;

  function setUp() public {
    contracts = new DeployV2().run();
    weth = ERC20(MAINNET_WETH);
  }

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

  modifier addWEthVault() {
    contracts.vaultManager.add(DNFT_ID_1, address(contracts.ethVault));
    _;
  }

  function test_AddVault() 
    public 
      mintDNft 
      addWEthVault 
  {
    address firstVault = contracts.vaultManager.getVaults(DNFT_ID_1)[0];
    assertEq(firstVault, address(contracts.ethVault));
  }

  modifier depositEth(uint amount) {
    deal(MAINNET_WETH, address(this), amount);
    weth.approve(address(contracts.vaultManager), amount);
    contracts.vaultManager.deposit(DNFT_ID_1, address(contracts.ethVault), amount);
    _;
  }

  function test_Deposit() 
    public 
      mintDNft 
      addWEthVault 
      depositEth(100 ether)
  {
    assertEq(contracts.ethVault.id2asset(DNFT_ID_1), 100 ether);
  }

  modifier skip1Block() {
    vm.roll(block.number + 1);
    _;
  }

  modifier withdrawEth(uint amount) {
    contracts.vaultManager.withdraw(
      DNFT_ID_1,
      address(contracts.ethVault),
      amount,
      address(this)
    );
    _;
  }

  function test_Withdraw() 
    public 
      mintDNft 
      addWEthVault 
      depositEth(100 ether)
      skip1Block
      withdrawEth(100 ether)
  {
    assertEq(contracts.ethVault.id2asset(DNFT_ID_1), 0 ether);
  }

  function testFail_DepositAndWithdrawInSameBlock() 
    public 
      mintDNft 
      addWEthVault 
      depositEth(100 ether)
      // skip1Block
      withdrawEth(100 ether)
  {
  }

  // --- RECEIVER ---

  receive() external payable {}

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure returns (bytes4) {
    return 0x150b7a02;
  }
}
