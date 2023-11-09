// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {DeployBase} from "../script/deploy/DeployBase.s.sol";
import {DNft} from "../src/core/DNft.sol";
import {Dyad} from "../src/core/Dyad.sol";
import {OracleMock} from "./OracleMock.sol";
import {Parameters} from "../src/Parameters.sol";

contract BaseTest is Test, Parameters {
  using stdStorage for StdStorage;

  DNft       dNft;
  Dyad       dyad;
  OracleMock oracleMock;

  receive() external payable {}

  function setUp() public {
    oracleMock = new OracleMock();
    DeployBase deployBase = new DeployBase();
    (address _dNft, address _dyad) = deployBase.deploy(
      address(oracleMock),
      MAINNET_OWNER
    );
    dNft    = DNft(_dNft);
    dyad    = Dyad(_dyad);
    vm.warp(block.timestamp + 1 days);
  }

  function overwriteNft(uint id, uint xp, uint deposit, uint withdrawal) public {
    stdstore.target(address(dNft)).sig("idToNft(uint256)").with_key(id)
      .depth(0).checked_write(xp);
    stdstore.target(address(dNft)).sig("idToNft(uint256)").with_key(id)
      .depth(1).checked_write(deposit);
    stdstore.target(address(dNft)).sig("idToNft(uint256)").with_key(id)
      .depth(2).checked_write(withdrawal);
  }

  function overwrite(address _contract, string memory signature, uint value) public {
    stdstore.target(_contract).sig(signature).checked_write(value); 
  }

  function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
    return 0x150b7a02;
  }
}
