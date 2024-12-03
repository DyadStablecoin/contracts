// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Owned} from "@solmate/src/auth/Owned.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Parameters} from "../params/Parameters.sol";
import {Kerosine} from "../staking/Kerosine.sol";
import {Dyad} from "../core/Dyad.sol";
import {KerosineManager} from "../core/KerosineManager.sol";
import {Vault} from "../core/Vault.sol";

contract KerosineDenominatorV3 is Owned {
    using EnumerableSet for EnumerableSet.AddressSet;
    using FixedPointMathLib for uint256;

    Kerosine public immutable KEROSINE;
    Dyad public immutable DYAD;
    KerosineManager public immutable MANAGER;

    uint64 public dyadMultiplierSnapshot = 1e12;
    uint64 public targetDyadMultiplier = 1e12;

    uint32 public dyadMultiplierSnapshotTimestamp;
    uint32 public targetDyadMultiplierTimestamp;

    EnumerableSet.AddressSet private _excludedAddresses;

    event DyadMultiplierUpdated(uint64 previous, uint64 target, uint32 fromTimestamp, uint32 toTimestamp);

    error TargetMultiplierTooSmall();

    constructor(Kerosine _kerosine, Dyad _dyad, KerosineManager _manager)
        Owned(0xDeD796De6a14E255487191963dEe436c45995813)
    {
        KEROSINE = _kerosine;
        DYAD = _dyad;
        MANAGER = _manager;
        _excludedAddresses.add(0xDeD796De6a14E255487191963dEe436c45995813); // Team Multisig
        _excludedAddresses.add(0x3962f6585946823440d274aD7C719B02b49DE51E); // Sablier Linear Lockup
    }

    function setAddressExcluded(address _address, bool exclude) external onlyOwner {
        if (exclude) {
            _excludedAddresses.add(_address);
        } else {
            _excludedAddresses.remove(_address);
        }
    }

    function setTargetDyadMultiplier(uint64 _targetMultiplier, uint32 _duration) external onlyOwner {
        if (_targetMultiplier <= 1e12) {
            revert TargetMultiplierTooSmall();
        }

        uint64 previousMultiplier = _getDyadSupplyMultiplier();

        dyadMultiplierSnapshot = previousMultiplier;
        targetDyadMultiplier = _targetMultiplier;
        dyadMultiplierSnapshotTimestamp = uint32(block.timestamp);
        targetDyadMultiplierTimestamp = uint32(block.timestamp) + _duration;

        emit DyadMultiplierUpdated(
            previousMultiplier, _targetMultiplier, uint32(block.timestamp), uint32(block.timestamp) + _duration
        );
    }

    function currentDyadMultiplier() external view returns (uint64) {
        return _getDyadSupplyMultiplier();
    }

    function isExcludedAddress(address _address) external view returns (bool) {
        return _excludedAddresses.contains(_address);
    }

    function excludedAddresses() external view returns (address[] memory) {
        return _excludedAddresses.values();
    }

    function denominator() external view returns (uint256) {
        uint256 adjustedKerosineSupply = KEROSINE.totalSupply();
        uint256 excludedAddressLength = _excludedAddresses.length();
        for (uint256 i = 0; i < excludedAddressLength; ++i) {
            adjustedKerosineSupply -= KEROSINE.balanceOf(_excludedAddresses.at(i));
        }

        uint256 dyadMultiplier = _getDyadSupplyMultiplier();

        // Return early if multiplier is 1
        if (dyadMultiplier == 1e12) {
            return adjustedKerosineSupply;
        }

        uint256 dyadSupply = DYAD.totalSupply();

        uint256 tvl = _getTvl();

        uint256 normalizedSupply = dyadSupply.mulDiv(dyadMultiplier, 1e12);

        if (normalizedSupply > tvl) {
            return type(uint256).max;
        }

        return (tvl - dyadSupply).mulDiv(adjustedKerosineSupply, tvl - normalizedSupply);
    }

    function _getTvl() internal view returns (uint256) {
        uint256 tvl;
        address[] memory vaults = MANAGER.getVaults();
        uint256 numberOfVaults = vaults.length;
        for (uint256 i = 0; i < numberOfVaults; i++) {
            Vault vault = Vault(vaults[i]);
            ERC20 asset = vault.asset();
            tvl += asset.balanceOf(address(vault)) * vault.assetPrice() * 1e18 / (10 ** asset.decimals())
                / (10 ** vault.oracle().decimals());
        }

        return tvl;
    }

    function _getDyadSupplyMultiplier() internal view returns (uint64) {
        uint32 targetTimestamp = targetDyadMultiplierTimestamp;
        if (block.timestamp >= targetTimestamp) {
            return targetDyadMultiplier;
        }

        uint64 target = targetDyadMultiplier;
        uint64 snapshot = dyadMultiplierSnapshot;
        uint32 snapshotTimestamp = dyadMultiplierSnapshotTimestamp;

        uint32 timeDelta = targetTimestamp - snapshotTimestamp;
        uint64 multiplierDelta = target > snapshot ? target - snapshot : snapshot - target;

        uint64 ratePerSecond = multiplierDelta / timeDelta;

        uint32 secondsPassed = uint32(block.timestamp) - snapshotTimestamp;

        if (target > snapshot) {
            return snapshot + (secondsPassed * ratePerSecond);
        }

        return snapshot - (secondsPassed * ratePerSecond);
    }
}
