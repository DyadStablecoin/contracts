// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {Staking} from "./Staking.sol";

struct PayoutSplit {
    address recipient;
    uint96 amount;
}

contract Ignition is Owned {

    error Unauthorized();

    ERC20 public immutable kerosene;
    Staking public immutable staking;
    address public immutable vaultManager;
    PayoutSplit[] public payments;
    
    
    mapping(uint256 noteId => uint256 totalIgnited) public totalIgnited;

    constructor(address _kerosene, address _owner, Staking _staking, address _vaultManager) Owned(_owner) {
        kerosene = ERC20(_kerosene);
        payments.push(PayoutSplit(_owner, 10000));
        staking = _staking;
        vaultManager = _vaultManager;
    }

    function ignite(uint256 noteId, uint256 amount) external {
        kerosene.transferFrom(msg.sender, address(this), amount);
        uint256 amountRemaining = amount;
        for (uint256 i = 0; i < payments.length; i++) {
            if (i == payments.length - 1) {
                kerosene.transfer(payments[i].recipient, amountRemaining);
            } else {
                uint256 amountToSend = (amountRemaining * payments[i].amount) / 10000;
                kerosene.transfer(payments[i].recipient, amountToSend);
                amountRemaining -= amountToSend;
            }
        }
        totalIgnited[noteId] += amount;
        staking.updateBoost(noteId);
    }

    function grantBoost(uint256 noteId, uint256 boost) external {
        if (msg.sender != vaultManager) {
            if (msg.sender != owner) {
                revert Unauthorized();
            }
        }
        totalIgnited[noteId] += boost;
        staking.updateBoost(noteId);
    }

    function setPayouts(PayoutSplit[] calldata _payments) external onlyOwner {
        uint256 totalPayout = 0;
        for (uint256 i; i < _payments.length; ++i) {
            totalPayout += _payments[i].amount;
        }
        require(totalPayout == 10000, "Total payout must be 100%");
        payments = _payments;
    }
}
