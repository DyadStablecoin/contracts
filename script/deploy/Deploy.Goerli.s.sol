// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {DeployBase} from "./DeployBase.s.sol";
import {Parameters} from "../../src/params/Parameters.sol";

contract DeployGoerli is Script, Parameters {
    function run() public {
        new DeployBase().deploy(
            GOERLI_OWNER, GOERLI_DNFT, GOERLI_WETH, GOERLI_WETH_ORACLE, GOERLI_FEE, GOERLI_FEE_RECIPIENT
        );
    }
}
