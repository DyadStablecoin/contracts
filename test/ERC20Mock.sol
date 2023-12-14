// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib}   from "@solmate/src/utils/SafeTransferLib.sol";

contract ERC20Mock is ERC20 {
  using SafeTransferLib for address;

  constructor(string memory name, string memory symbol) ERC20(name, symbol, 18) {}

  event Deposit(address indexed from, uint256 amount);

  event Withdrawal(address indexed to, uint256 amount);

  function deposit() public payable virtual {
      _mint(msg.sender, msg.value);

      emit Deposit(msg.sender, msg.value);
  }

  function withdraw(uint256 amount) public virtual {
      _burn(msg.sender, amount);

      emit Withdrawal(msg.sender, amount);

      msg.sender.safeTransferETH(amount);
  }

  function mint(address to, uint256 amount) external virtual {
      _mint(to, amount);
  }

  receive() external payable virtual {
      deposit();
  }
}
