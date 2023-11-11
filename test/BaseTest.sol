// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {DeployBase, Contracts} from "../script/deploy/DeployBase.s.sol";
import {Parameters} from "../src/Parameters.sol";

contract BaseTest is Test, Parameters {

  function setUp() public {
    Contracts memory contracts = new DeployBase().deploy(
      msg.sender,
      GOERLI_DNFT,
      GOERLI_WETH,
      GOERLI_WETH_ORACLE
    );
  }

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

