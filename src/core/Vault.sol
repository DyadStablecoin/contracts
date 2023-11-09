// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {Owned} from "@solmate/src/auth/Owned.sol";

import {IDNft} from "../interfaces/IDNft.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IAggregatorV3} from "../interfaces/AggregatorV3Interface.sol";
import {Dyad} from "./Dyad.sol";

contract Vault is Owned, IVault {
  using SafeTransferLib   for address;
  using SafeCast          for int;
  using FixedPointMathLib for uint;

  uint public constant MIN_COLLATERIZATION_RATIO = 3e18; // 300%

  struct Permission {
    bool    hasPermission; 
    uint248 lastUpdated;
  }

  mapping(uint => uint)                            public id2eth;
  mapping(uint => uint)                            public id2dyad;

  Dyad          public dyad;
  IAggregatorV3 public oracle;

  constructor(
      address _dyad,
      address _oracle, 
      address _owner
  ) Owned(_owner) {
      dyad   = Dyad(_dyad);
      oracle = IAggregatorV3(_oracle);
  }

  /// @inheritdoc IVault
  function deposit(uint id) 
    external 
    payable
  {
    id2eth[id] += msg.value;
    emit Deposit(id, msg.value);
  }

  /// @inheritdoc IVault
  function withdraw(uint from, address to, uint amount) 
    external 
    {
      id2eth[from] -= amount;
      if (_collatRatio(from) < MIN_COLLATERIZATION_RATIO) revert CrTooLow(); 
      to.safeTransferETH(amount); // re-entrancy
      emit Withdraw(from, to, amount);
  }

  /// @inheritdoc IVault
  function mintDyad(uint from, address to, uint amount)
    external 
    {
      id2dyad[from] += amount;
      if (_collatRatio(from) < MIN_COLLATERIZATION_RATIO) revert CrTooLow(); 
      dyad.mint(to, amount);
      emit MintDyad(from, to, amount);
  }

  /// @inheritdoc IVault
  function burnDyad(uint id, uint amount) 
    external 
  {
    dyad.burn(msg.sender, amount);
    id2dyad[id] -= amount;
    emit BurnDyad(id, amount);
  }

  /// @inheritdoc IVault
  function redeem(uint from, address to, uint amount)
    external 
    returns (uint) { 
      dyad.burn(msg.sender, amount);
      id2dyad[from] -= amount;
      uint eth       = amount * (10**oracle.decimals()) / _getEthPrice();
      id2eth[from]  -= eth;
      to.safeTransferETH(eth); // re-entrancy 
      emit Redeem(from, amount, to, eth);
      return eth;
  }

  // Get Collateralization Ratio of the dNFT
  function _collatRatio(uint id) 
    private 
    view 
    returns (uint) {
      uint _dyad = id2dyad[id]; // save gas
      if (_dyad == 0) return type(uint).max;
      // cr = deposit / withdrawn
      return (id2eth[id] * _getEthPrice() / (10**oracle.decimals())).divWadDown(_dyad);
  }

  // ETH price in USD
  function _getEthPrice() 
    private 
    view 
    returns (uint) {
      (
        uint80 roundID,
        int256 price,
        , 
        uint256 timeStamp, 
        uint80 answeredInRound
      ) = oracle.latestRoundData();
      if (timeStamp == 0) revert IncompleteRound();
      if (answeredInRound < roundID) revert StaleData();
      return price.toUint256();
  }
}
