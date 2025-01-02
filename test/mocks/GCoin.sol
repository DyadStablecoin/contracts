// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract GCoin is ERC20("G Coin", "GC", 18) {
    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
