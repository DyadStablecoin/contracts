// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {VaultManager}    from "./VaultManager.sol";
import {DNft}            from "../../src/core/DNft.sol";
import {Dyad}            from "../../src/core/Dyad.sol";
import {Licenser}        from "../../src/core/Licenser.sol";
import {KerosineManager} from "../../src/core/KerosineManager.sol";
import {Vault}           from "../../src/core/Vault.sol";

// @dev: Same as VaultManager but with flash loan protection.
contract VaultManagerV2 is VaultManager {

  KerosineManager public kerosineManager;
  
  error DepositedInSameBlock();
  error NotEnoughExoCollat();   // Not enough exogenous collateral

  mapping (uint => uint) public idToBlockOfLastDeposit;

  constructor(
    DNft     dNft,
    Dyad     dyad,
    Licenser licenser
  ) VaultManager(dNft, dyad, licenser) {}

  function setKerosineManager(
    KerosineManager _kerosineManager
  ) 
    external 
  {
    kerosineManager = _kerosineManager;
  }

  /// @inheritdoc VaultManager
  function deposit(
    uint    id,
    address vault,
    uint    amount
  ) 
    override
    public 
      isValidDNft(id) 
  {
    idToBlockOfLastDeposit[id] = block.number;
    super.deposit(id, vault, amount);
  }

  /// @inheritdoc VaultManager
  function withdraw(
    uint    id,
    address vault,
    uint    amount,
    address to
  ) 
    override
    public 
      isDNftOwner(id)
  {
    if (idToBlockOfLastDeposit[id] == block.number)    revert DepositedInSameBlock();
    uint dyadMinted = dyad.mintedDyad(address(this), id);
    if (getNonKeroseneValue(id) - amount < dyadMinted) revert NotEnoughExoCollat();
    super.withdraw(id, vault, amount, to);
  }

  function mintDyad(
    uint    id,
    uint    amount,
    address to
  ) 
    override  
    public
      isDNftOwner(id)
  {
    uint newDyadMinted = dyad.mintedDyad(address(this), id) + amount;
    if (getNonKeroseneValue(id) < newDyadMinted) revert NotEnoughExoCollat();
    super.mintDyad(id, amount, to);
  }

  function getNonKeroseneValue(
    uint id
  ) 
    public 
    view 
    returns (uint) 
  {
    uint totalUsdValue;
    address[] memory vaults = kerosineManager.getVaults();
    uint numberOfVaults = vaults.length;
    for (uint i = 0; i < numberOfVaults; i++) {
      totalUsdValue += Vault(vaults[i]).getUsdValue(id);
    }
    return totalUsdValue;
  }
}
