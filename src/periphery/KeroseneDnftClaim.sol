// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Owned} from "solmate/auth/Owned.sol";
import {IERC721Enumerable, IERC721TokenReceiver} from "forge-std/interfaces/IERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";

contract KeroseneDnftClaim is Owned, IERC721TokenReceiver {
    error NotNote();
    error SoldOut();
    error InvalidProof();
    error AlreadyPurchased();

    address constant RECEIVER = 0xDeD796De6a14E255487191963dEe436c45995813;

    IERC721Enumerable public immutable DNFT;
    ERC20 public immutable KEROSENE;

    uint256 public price;
    bytes32 public merkleRoot;

    mapping(address => bool) public purchased;

    constructor(
        address dnft,
        address kerosene,
        uint256 price_,
        bytes32 root_
    ) Owned(tx.origin) {
        DNFT = IERC721Enumerable(dnft);
        KEROSENE = ERC20(kerosene);
        price = price_;
        merkleRoot = root_;
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4) {
        if (msg.sender != address(DNFT)) {
            revert NotNote();
        }
        return KeroseneDnftClaim.onERC721Received.selector;
    }

    function buyNote(bytes32[] calldata proof) external {
        uint256 balance = DNFT.balanceOf(address(this));
        if (balance == 0) {
            revert SoldOut();
        }
        if (purchased[msg.sender]) {
            revert AlreadyPurchased();
        }
        if (!MerkleProofLib.verify(proof, merkleRoot, keccak256(abi.encode(msg.sender)))) {
            revert InvalidProof();
        }

        purchased[msg.sender] = true;

        // transfer payment from the
        KEROSENE.transferFrom(msg.sender, RECEIVER, price);
        // transfer the last token owned to save gas
        uint256 tokenId = DNFT.tokenOfOwnerByIndex(address(this), balance - 1);
        DNFT.transferFrom(address(this), msg.sender, tokenId);
    }

    function sweepERC20(address token) external onlyOwner {
        uint256 balance = ERC20(token).balanceOf(address(this));
        SafeTransferLib.safeTransfer(ERC20(token), msg.sender, balance);
    }

    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
    }

    function setPrice(uint256 price_) external onlyOwner {
        price = price_;
    }
}
