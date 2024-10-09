// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDyad} from "../interfaces/IDyad.sol";
import {Licenser} from "./Licenser.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract Dyad is ERC20("DYAD Stable", "DYAD", 18), IDyad {
    Licenser public immutable licenser;

    // dNFT ID => dyad
    mapping(uint256 => uint256) public mintedDyad;

    constructor(Licenser _licenser) {
        licenser = _licenser;
    }

    modifier licensedVaultManager() {
        if (!licenser.isLicensed(msg.sender)) revert NotLicensed();
        _;
    }

    /// @inheritdoc IDyad
    function mint(uint256 id, address to, uint256 amount) external licensedVaultManager {
        _mint(to, amount);
        mintedDyad[id] += amount;
    }

    /// @inheritdoc IDyad
    function burn(uint256 id, address from, uint256 amount) external licensedVaultManager {
        _burn(from, amount);
        mintedDyad[id] -= amount;
    }
}
