// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {DNft} from "src/core/DNft.sol";
import {Dyad} from "src/core/Dyad.sol";
import {Vault} from "src/core/Vault.sol";
import {VaultManager} from "src/core/VaultManager.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {OracleMock} from "./OracleMock.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @author philogy <https://github.com/philogy>
contract Handler is CommonBase, StdCheats, StdUtils {
    using EnumerableSet for EnumerableSet.AddressSet;

    DNft internal immutable dnft;
    Dyad internal immutable dyad;
    VaultManager internal immutable manager;
    Vault[] internal vaults;

    EnumerableSet.AddressSet internal actors;

    uint256 internal constant SANE_CONSTANT_CAP = 10_000_000;

    constructor(DNft _dnft, Dyad _dyad, VaultManager _manager, Vault[] memory _vaults) {
        dnft = _dnft;
        dyad = _dyad;
        manager = _manager;
        vaults = _vaults;
    }

    function deposit(uint256 idSeed, uint256 vaultSeed, uint256 amount) public {
        uint256 id = randDNftId(idSeed);
        address actor = dnft.ownerOf(id);
        Vault vault = randVault(vaultSeed);
        amount = bound(amount, 0, SANE_CONSTANT_CAP * 10 ** vault.asset().decimals());
        ERC20Mock asset = ERC20Mock(address(vault.asset()));
        asset.mint(actor, amount);
        // Assumption (non-critical): `deposit` caller is always dnft owner
        vm.startPrank(actor);
        asset.approve(address(manager), amount);
        manager.deposit(id, address(vault), amount);
        vm.stopPrank();
    }

    function withdraw(uint256 idSeed, uint256 vaultSeed, uint256 amount) public {
        uint256 id = randDNftId(idSeed);
        address actor = dnft.ownerOf(id);
        Vault vault = randVault(vaultSeed);
        amount = bound(amount, 0, vault.id2asset(id));
        // Assumption (non-critical): `withdraw` caller is always dnft owner
        // Assumption (wrong): CR is sufficient
        vm.prank(actor);
        manager.withdraw(id, address(vault), amount, actor);
    }

    function getActors() public view returns (address[] memory) {
        return actors.values();
    }

    function nextSeed(uint256 seed) internal pure returns (uint256 newSeed) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, seed)
            newSeed := keccak256(0x00, 0x20)
        }
    }

    function randVault(uint256 seed) internal view returns (Vault) {
        return vaults[seed % vaults.length];
    }

    function randActor(uint256 seed) internal view returns (address) {
        return actors.at(seed % actors.length());
    }

    function randDNftId(uint256 seed) internal view returns (uint256) {
        return seed % dnft.totalSupply();
    }
}
