// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";
import {Owned} from "@solmate/src/auth/Owned.sol";
import {IDNft} from "../interfaces/IDNft.sol";
import {DNftParameters} from "../params/DNftParameters.sol";

contract DNft is ERC721Enumerable, Owned, DNftParameters, IDNft {
    using SafeTransferLib for address;

    uint256 public publicMints; // Number of public mints
    uint256 public insiderMints; // Number of insider mints

    constructor() ERC721("Dyad NFT", "dNFT") Owned(msg.sender) {}

    /// @inheritdoc IDNft
    function mintNft(address to) external payable returns (uint256) {
        uint256 price = START_PRICE + (PRICE_INCREASE * publicMints++);
        if (msg.value < price) revert InsufficientFunds();
        uint256 id = _mintNft(to);
        if (msg.value > price) to.safeTransferETH(msg.value - price);
        emit MintedNft(id, to);
        return id;
    }

    /// @inheritdoc IDNft
    function mintInsiderNft(address to) external onlyOwner returns (uint256) {
        if (++insiderMints > INSIDER_MINTS) revert InsiderMintsExceeded();
        uint256 id = _mintNft(to);
        emit MintedInsiderNft(id, to);
        return id;
    }

    function _mintNft(address to) private returns (uint256) {
        uint256 id = totalSupply();
        _safeMint(to, id);
        return id;
    }

    /// @inheritdoc IDNft
    function drain(address to) external onlyOwner {
        uint256 balance = address(this).balance;
        to.safeTransferETH(balance);
        emit Drained(to, balance);
    }
}
