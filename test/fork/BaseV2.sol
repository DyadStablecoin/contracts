// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Parameters}          from "../../src/params/Parameters.sol";
import {Licenser}            from "../../src/core/Licenser.sol";
import {Modifiers}           from "../Modifiers.sol";
import {DeployV2, Contracts} from "../../script/deploy/Deploy.V2.s.sol";

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract BaseTestV2 is Modifiers, Parameters {
  Contracts contracts;
  ERC20 weth;

  uint constant ETH_TO_USD = 3545;

  uint alice0;
  uint alice1;
  uint bob0;
  uint bob1;

  address alice;
  address bob = address(0x42);

  function setUp() public {
    contracts = new DeployV2().run();
    weth      = ERC20(MAINNET_WETH);
    alice     = address(this);

    licenseVauleManager();
  }

  // --- alice ---
  modifier mintAlice0() { alice0 = mintDNft(address(this)); _; }
  modifier mintAlice1() { alice1 = mintDNft(address(this)); _; }
  // --- bob ---
  modifier mintBob0() { bob0 = mintDNft(bob); _; }
  modifier mintBob1() { bob1 = mintDNft(bob); _; }

  function mintDNft(address owner) public returns(uint id) {
    uint startPrice    = contracts.dNft.START_PRICE();
    uint priceIncrease = contracts.dNft.PRICE_INCREASE();
    uint publicMints   = contracts.dNft.publicMints();
    uint price = startPrice + (priceIncrease * publicMints);
    vm.deal(address(this), price);
    id = contracts.dNft.mintNft{value: price}(owner);
  }

  function licenseVauleManager() public {
    Licenser licenser = Licenser(MAINNET_VAULT_MANAGER_LICENSER);
    vm.prank(MAINNET_OWNER);
    licenser.add(address(contracts.vaultManager));
  }

  // -- helpers --
  function _ethToUSD(uint eth) public pure returns (uint) {
    return eth * ETH_TO_USD;
  }

  function getMintedDyad(uint id) public view returns (uint) {
    return contracts.dyad.mintedDyad(address(contracts.vaultManager), id);
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
