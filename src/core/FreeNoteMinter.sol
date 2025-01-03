// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Owned} from "@solmate/src/auth/Owned.sol";
import {ReentrancyGuard} from "@solmate/src/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {DNft} from "./DNft.sol";

contract FreeNoteMinter is Owned, ReentrancyGuard, IERC721Receiver {
    DNft public immutable dnft;

    error NotEnoughBalance();

    constructor(address _dnftAddress) Owned(msg.sender) {
        dnft = DNft(_dnftAddress);
    }

    receive() external payable {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function mint() external nonReentrant returns (uint256) {
        return _mint(msg.sender);
    }

    function mint(address _receiver) external nonReentrant returns (uint256) {
        return _mint(_receiver);
    }

    function transferDNftOwnership(address _newOwner) external onlyOwner {
        dnft.transferOwnership(_newOwner);
    }

    function recoverEth() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function _mint(address _receiver) internal returns (uint256) {
        uint256 price = _calculateMintPrice();

        if (price > address(this).balance) {
            revert NotEnoughBalance();
        }

        uint256 nftID = dnft.mintNft{value: price}(address(this));

        dnft.drain(address(this));

        dnft.safeTransferFrom(address(this), _receiver, nftID);

        return nftID;
    }

    function _calculateMintPrice() internal view returns (uint256) {
        uint256 numberOfMints = dnft.publicMints();
        uint256 baseMintPrice = dnft.START_PRICE();
        uint256 mintPriceIncrease = dnft.PRICE_INCREASE();

        return baseMintPrice + (mintPriceIncrease * numberOfMints);
    }
}
