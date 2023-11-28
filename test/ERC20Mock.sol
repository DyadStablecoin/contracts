// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol, 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
