// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Claimer is AccessControl, Pausable {
    using SafeERC20 for IERC20;

    error InvalidProof();

    event Claimed(address indexed to, uint256 amount, uint256 totalClaimed);

    IERC20 public immutable token;

    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    bytes32 public merkleRoot;
    uint256 public totalClaimed;

    mapping(address => uint256) public claimedAmount;

    constructor(address defaultAdmin, address tokenAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        token = IERC20(tokenAddress);
    }

    function claim(address to, uint256 amount, bytes32[] calldata proof)
        external
        onlyRole(DISTRIBUTOR_ROLE)
        whenNotPaused
        returns (uint256)
    {
        bytes32 leaf = keccak256(abi.encodePacked(to, amount));
        if (!MerkleProof.verifyCalldata(proof, merkleRoot, leaf)) {
            revert InvalidProof();
        }

        uint256 alreadyClaimed = claimedAmount[to];
        uint256 transferAmount = amount - alreadyClaimed;
        claimedAmount[to] = alreadyClaimed + transferAmount;
        totalClaimed += transferAmount;

        token.safeTransfer(to, transferAmount);

        emit Claimed(to, transferAmount, alreadyClaimed + transferAmount);

        return transferAmount;
    }

    function setMerkleRoot(bytes32 root) external onlyRole(DISTRIBUTOR_ROLE) {
        merkleRoot = root;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function withdrawERC20(address tokenAddress, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(tokenAddress).safeTransfer(to, amount);
    }
}
