// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

contract DyadLPStaking is Ownable {
    using SafeTransferLib for address;

    error NotOwnerOfNote();

    event Deposited(uint256 indexed noteId, uint256 indexed amount);
    event Withdrawn(uint256 indexed noteId, uint256 indexed amount);

    address public immutable lpToken;
    IERC721 public immutable dnft;

    uint256 public totalLP;

    mapping(uint256 noteId => uint256 amount) public noteIdToAmountDeposited;

    constructor(address _lpToken, address _dnft, address _owner) {
        lpToken = _lpToken;
        dnft = IERC721(_dnft);
        _initializeOwner(_owner);
    }

    function name() public view returns (string memory) {
        return string.concat(IERC20(lpToken).name(), " LP Staking");
    }

    function deposit(uint256 noteId, uint256 amount) public {
        require(dnft.ownerOf(noteId) != address(0), "Invalid NoteId");
        totalLP += amount;
        noteIdToAmountDeposited[noteId] += amount;
        lpToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(noteId, amount);
    }

    function withdraw(uint256 noteId, uint256 amount) public {
        address owner = dnft.ownerOf(noteId);
        require(msg.sender == owner, NotOwnerOfNote());
        totalLP -= amount;
        noteIdToAmountDeposited[noteId] -= amount;
        lpToken.safeTransfer(owner, amount);

        emit Withdrawn(noteId, amount);
    }

    function recoverERC20(address token) public onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (token == address(lpToken)) {
            // lpToken is staked by users so the only amount that should be recoverable is tokens
            // that are sent accidentally without using the deposit function
            amount -= totalLP;
        }
        token.safeTransfer(msg.sender, amount);
    }

    function recoverERC721(address token, uint256 tokenId) public onlyOwner {
        IERC721(token).transferFrom(address(this), msg.sender, tokenId);
    }
}
