// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {DNft} from "../core/DNft.sol";
import {IExtension} from "../interfaces/IExtension.sol";

contract DyadLPStaking is OwnableRoles, IExtension {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    error NotOwnerOfNote();
    error InvalidProof();

    event Claimed(uint256 indexed noteId, uint256 indexed amount, uint256 unclaimedBonus);

    uint256 public constant MANAGER_ROLE = _ROLE_0;

    address public immutable lpToken;
    address public immutable kerosene;
    DNft public immutable dnft;
    address public immutable keroseneVault;
    IVaultManager public immutable vaultManager;

    bytes32 public merkleRoot;

    uint256 public unclaimedBonus;

    mapping(uint256 noteId => uint256 amount) public noteIdToAmountDeposited;
    mapping(uint256 noteId => uint256 amount) public noteIdToTotalClaimed;

    constructor(address _lpToken, address _kerosene, address _dnft, address _keroseneVault, address _vaultManager) {
        lpToken = _lpToken;
        kerosene = _kerosene;
        dnft = DNft(_dnft);
        keroseneVault = _keroseneVault;
        vaultManager = IVaultManager(_vaultManager);
        _initializeOwner(msg.sender);
    }

    function name() public pure override returns (string memory) {
        return "Dyad LP Staking";
    }

    function description() public pure override returns (string memory) {
        return "Stake LP tokens to earn Kerosene";
    }

    function getHookFlags() public pure override returns (uint256) {
        return 0;
    }

    function totalLP() public view returns (uint256) {
        return lpToken.balanceOf(address(this));
    }

    function deposit(uint256 noteId, uint256 amount) public {
        noteIdToAmountDeposited[noteId] += amount;
        lpToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 noteId, uint256 amount) public {
        address owner = dnft.ownerOf(noteId);
        require(msg.sender == owner, NotOwnerOfNote());
        
        noteIdToAmountDeposited[noteId] -= amount;
        lpToken.safeTransfer(owner, amount);
    }

    function setRoot(bytes32 _merkleRoot) public onlyRoles(MANAGER_ROLE) {
        merkleRoot = _merkleRoot;
    }

    function claim(uint256 noteId, uint256 amount, bytes32[] calldata proof) public returns (uint256) {
        address noteOwner = dnft.ownerOf(noteId);
        require(msg.sender == noteOwner, NotOwnerOfNote());

        _verifyProof(noteId, amount, proof);
        uint256 amountToSend = _syncClaimableAmount(noteId, amount);
        uint256 claimSubBonus = amountToSend.mulDiv(80, 100);
        uint256 unclaimed = amountToSend - claimSubBonus;
        unclaimedBonus += unclaimed;

        kerosene.safeTransfer(noteOwner, claimSubBonus);

        emit Claimed(noteId, claimSubBonus, unclaimed);

        return claimSubBonus;
    }

    function claimToVault(uint256 noteId, uint256 amount, bytes32[] calldata proof) public returns (uint256) {
        require(msg.sender == dnft.ownerOf(noteId), NotOwnerOfNote());

        _verifyProof(noteId, amount, proof);
        uint256 amountToSend = _syncClaimableAmount(noteId, amount);

        kerosene.safeApprove(address(vaultManager), amountToSend);
        vaultManager.deposit(noteId, keroseneVault, amountToSend);

        emit Claimed(noteId, amountToSend, 0);

        return amountToSend;
    }

    function _verifyProof(uint256 noteId, uint256 amount, bytes32[] calldata proof) internal view {
        // double hash to prevent second preimage attack
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encodePacked(noteId, amount))));
        require(MerkleProofLib.verifyCalldata(proof, merkleRoot, leaf), InvalidProof());
    }

    function _syncClaimableAmount(uint256 noteId, uint256 amount) private returns (uint256) {
        uint256 alreadyClaimed = noteIdToTotalClaimed[noteId];
        uint256 amountToSend = amount - alreadyClaimed;
        if (amountToSend == 0) {
            return 0;
        }
        noteIdToTotalClaimed[noteId] += amountToSend;

        return amountToSend;
    }

    function depositForRewards(uint256 amount) public onlyOwnerOrRoles(MANAGER_ROLE) {
        uint256 previousUnclaimedBonus = unclaimedBonus;
        unclaimedBonus = 0;
        if (amount < previousUnclaimedBonus) {
            kerosene.safeTransferFrom(address(this), msg.sender, previousUnclaimedBonus - amount);
        } else if (amount > previousUnclaimedBonus) {
            kerosene.safeTransferFrom(msg.sender, address(this), amount - previousUnclaimedBonus);
        }
    }
}
