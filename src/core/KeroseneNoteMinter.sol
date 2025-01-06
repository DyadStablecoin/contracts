// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {DNft} from "./DNft.sol";

contract KeroseneNoteMinter is Owned, ReentrancyGuard, IERC721Receiver {
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    ERC20 public immutable KERO;
    DNft public immutable NOTES;
    uint256 public immutable BASE_NOTE_PRICE;
    uint256 public immutable NOTE_PRICE_INCREASE;

    uint256 public price = 1e18;

    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event KeroNoteMinted(address indexed receiver, uint256 indexed noteID);

    error NotEnoughBalance();

    constructor(address _keroAddress, address _dnftAddress) Owned(msg.sender) {
        KERO = ERC20(_keroAddress);
        NOTES = DNft(_dnftAddress);

        BASE_NOTE_PRICE = NOTES.START_PRICE();
        NOTE_PRICE_INCREASE = NOTES.PRICE_INCREASE();
    }

    receive() external payable {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setPrice(uint256 _newPrice) external onlyOwner {
        uint256 oldPrice = price;

        price = _newPrice;

        emit PriceUpdated(oldPrice, _newPrice);
    }

    function mint() external nonReentrant returns (uint256) {
        return _mint(msg.sender);
    }

    function mint(address _receiver) external nonReentrant returns (uint256) {
        return _mint(_receiver);
    }

    function drain() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function transferDNftOwnership(address _newOwner) external onlyOwner {
        NOTES.transferOwnership(_newOwner);
    }

    function _mint(address _receiver) internal returns (uint256) {
        if (price > 0) {
            KERO.transferFrom(msg.sender, BURN_ADDRESS, price);
        }

        uint256 noteMintPrice = _calculateMintPrice();

        if (noteMintPrice > address(this).balance) {
            revert NotEnoughBalance();
        }

        uint256 noteID = NOTES.mintNft{value: noteMintPrice}(address(this));

        NOTES.drain(address(this));

        NOTES.safeTransferFrom(address(this), _receiver, noteID);

        emit KeroNoteMinted(_receiver, noteID);

        return noteID;
    }

    function _calculateMintPrice() internal view returns (uint256) {
        uint256 numberOfMints = NOTES.publicMints();

        return BASE_NOTE_PRICE + (NOTE_PRICE_INCREASE * numberOfMints);
    }
}
