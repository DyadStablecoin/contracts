// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVaultManager} from "../../src/interfaces/IVaultManager.sol";
import {IDNft} from "../../src/interfaces/IDNft.sol";
import {IVault} from "../../src/interfaces/IVault.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";
import {DNft} from "../../src/core/DNft.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {Owned} from "@solmate/src/auth/Owned.sol";
import {OracleMock} from "../OracleMock.sol";

import {GCoin} from "./GCoin.sol";

contract VaultGCoin is IVault, Owned {
    using SafeTransferLib for ERC20;
    using SafeCast for int256;
    using FixedPointMathLib for uint256;

    error ExceedsDepositCap();

    uint256 public constant STALE_DATA_TIMEOUT = 36 hours;

    IVaultManager public immutable vaultManager;
    ERC20 public immutable asset;
    IAggregatorV3 public immutable oracle;
    DNft public immutable dNft;

    uint256 public depositCap;

    mapping(uint256 => uint256) public id2asset;

    modifier onlyVaultManager() {
        if (msg.sender != address(vaultManager)) revert NotVaultManager();
        _;
    }

    constructor(address owner, address _vaultManager, address _dNft) Owned(owner) {
        vaultManager = IVaultManager(_vaultManager);
        asset = new GCoin();
        dNft = DNft(_dNft);
        depositCap = type(uint256).max;
        oracle = IAggregatorV3(address(new OracleMock(1e8)));
    }

    function deposit(uint256 id, uint256 amount) external onlyVaultManager {
        id2asset[id] += amount;
        emit Deposit(id, amount);
    }

    function withdraw(uint256 id, address to, uint256 amount) external onlyVaultManager {
        id2asset[id] -= amount;
        asset.safeTransfer(to, amount);
        emit Withdraw(id, to, amount);
    }

    function move(uint256 from, uint256 to, uint256 amount) external onlyVaultManager {
        id2asset[from] -= amount;
        id2asset[to] += amount;
        emit Move(from, to, amount);
    }

    function getUsdValue(uint256 id) external view returns (uint256) {
        return id2asset[id] * assetPrice() * 1e18 / 10 ** oracle.decimals() / 10 ** asset.decimals();
    }

    function balanceOf(address account) external view returns (uint256 assetBalance) {
        uint256 dnftBalance = dNft.balanceOf(account);
        for (uint256 i; i < dnftBalance; ++i) {
            uint256 id = dNft.tokenOfOwnerByIndex(account, i);
            assetBalance += id2asset[id];
        }
    }

    function setDepositCap(uint256 _depositCap) external onlyOwner {
        depositCap = _depositCap;
    }

    function assetPrice() public view returns (uint256) {
        (, int256 answer,,,) = oracle.latestRoundData();
        return answer.toUint256();
    }

    function mintAsset(address _to, uint256 _amount) external {
        GCoin(address(asset)).mint(_to, _amount);
    }
}
