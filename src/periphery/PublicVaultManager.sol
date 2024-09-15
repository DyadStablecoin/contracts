// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VaultLicenser} from "./VaultLicenser.sol";
import { VaultManagerV5 } from "src/core/VaultManagerV5.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract PublicVaultManager is UUPSUpgradeable, OwnableUpgradeable {
    using FixedPointMathLib for uint256;

    uint256 public constant MIN_COLLAT_RATIO = 1.8e18; // 180% (in WAD)
    uint256 public constant LIQUIDATION_REWARD = 0.1e18; // 10% (in WAD)

    uint256 public NOTE_ID;
    VaultManagerV5 public vaultManager;
    ERC20 public dyad;

    struct Position {
        uint256 collateral;       // Collateral amount in asset tokens
        uint256 mintedDyad;       // Amount of DYAD minted
        uint256 lastDepositBlock; // Block number of the last deposit
    }

    mapping(address => EnumerableSet.AddressSet) internal vaults;
    mapping(address => mapping(address => Position)) public positions;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event MintDyad(address indexed user, uint256 amount);
    event BurnDyad(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed user, uint256 debtRepaid, uint256 collateralSeized);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(VaultManagerV5 _vaultManager, ERC20 _dyad) public initializer {
        vaultManager = _vaultManager;
        dyad = _dyad;
        __Ownable_init();
    }

    function setNoteId(uint256 _noteId) external onlyOwner {
        NOTE_ID = _noteId;
    }

    function addVault(address vault) external {
        vaults[msg.sender].add(vault);
    }

    function deposit(uint256 amount, address vault) external {
        Position storage position = positions[msg.sender][vault];
        position.lastDepositBlock = block.number;
        position.collateral += amount;
        vaultManager.deposit(NOTE_ID, amount, vault);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(address vault, uint256 amount) external {
        Position storage position = positions[msg.sender];
        require(block.number > position.lastDepositBlock, "Cannot withdraw in same block");
        require(position.collateral >= amount, "Not enough collateral");
        position.collateral -= amount;
        vaultManager.withdraw(amount, msg.sender);
        require(_collatRatio(position) >= MIN_COLLAT_RATIO, "Collateralization ratio too low");
        emit Withdraw(msg.sender, amount);
    }

    function mintDyad(uint256 amount) external {
        Position storage position = positions[msg.sender];
        position.mintedDyad += amount;
        require(_collatRatio(position) >= MIN_COLLAT_RATIO, "Collateralization ratio too low");
        dyad.mint(msg.sender, amount);
        emit MintDyad(msg.sender, amount);
    }

    function burnDyad(uint256 amount) external {
        Position storage position = positions[msg.sender];
        require(position.mintedDyad >= amount, "Not enough minted DYAD");
        position.mintedDyad -= amount;
        dyad.transferFrom(msg.sender, address(this), amount);
        dyad.burn(amount);
        emit BurnDyad(msg.sender, amount);
    }

    function liquidate(address user, uint256 amount) external {
        Position storage position = positions[user];
        require(_collatRatio(position) < MIN_COLLAT_RATIO, "Position is safe");
        uint256 userDebt = position.mintedDyad;
        require(userDebt >= amount, "Amount exceeds user debt");

        // Transfer DYAD from liquidator and burn it
        dyad.transferFrom(msg.sender, address(this), amount);
        dyad.burn(amount);

        // Calculate collateral to seize
        uint256 collateralValue = _collateralValue(position.collateral);
        uint256 liquidationReward = amount.mulWadDown(LIQUIDATION_REWARD);
        uint256 totalSeizeValue = amount.add(liquidationReward);

        uint256 collateralToSeize = totalSeizeValue.mulWadDown(position.collateral).divWadDown(userDebt);
        if (collateralToSeize > position.collateral) {
            collateralToSeize = position.collateral;
        }

        // Update user's position
        position.collateral -= collateralToSeize;
        position.mintedDyad -= amount;

        // Transfer collateral to liquidator
        vaultManager.withdraw(collateralToSeize, msg.sender);

        emit Liquidate(msg.sender, user, amount, collateralToSeize);
    }

    function _collatRatio(Position memory position) internal view returns (uint256) {
        if (position.mintedDyad == 0) return type(uint256).max;
        uint256 collateralValue = _collateralValue(position.collateral);
        return collateralValue.divWadDown(position.mintedDyad);
    }

    function _collateralValue(uint256 collateralAmount) internal view returns (uint256) {
        uint256 assetPrice = vault.assetPrice(); // Price with 18 decimals
        uint8 assetDecimals = vault.asset().decimals();
        return collateralAmount.mulDivDown(assetPrice, 10 ** assetDecimals);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}