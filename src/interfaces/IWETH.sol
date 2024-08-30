// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint) external;
}
