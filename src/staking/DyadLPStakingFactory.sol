import {Ownable} from "solady/auth/Ownable.sol";
import {DyadLPStaking} from "./DyadLPStaking.sol";
import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IExtension} from "../interfaces/IExtension.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

contract DyadLPStakingFactory is OwnableRoles, IExtension {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    error InvalidProof();
    error NotOwnerOfNote();
    error InvalidBlockNumber();
    error Paused();

    event PoolStakingCreated(address indexed lpToken, address indexed staking);
    event RewardRateSet(address indexed lpToken, uint256 oldRewardRate, uint256 newRewardRate);
    event Claimed(uint256 indexed noteId, uint256 indexed amount, uint256 unclaimedBonus);
    event RootUpdated(bytes32 newRoot, uint256 blockNumber);
    event RewardsDeposited(uint256 amount);

    uint256 public constant REWARDS_MANAGER_ROLE = _ROLE_0;
    uint256 public constant POOL_MANAGER_ROLE = _ROLE_1;

    address public immutable kerosene;
    IERC721 public immutable dnft;
    address public immutable keroseneVault;
    IVaultManager public immutable vaultManager;

    /// @notice lpToken to staking contract
    mapping(address lpToken => address staking) public lpTokenToStaking;

    /// @notice reward rate in kerosene per second emitted to the pool
    mapping(address lpToken => uint256 rewardRate) public lpTokenToRewardRate;

    /// @notice total amount of rewards claimed for a note
    mapping(uint256 noteId => uint256 amount) public noteIdToTotalClaimed;

    /// @notice merkle root for rewards distribution
    bytes32 public merkleRoot;

    /// @notice last block number when the root was updated
    uint256 public lastUpdateBlock;

    /// @notice total amount of rewards claimed
    uint128 public totalClaimed;

    /// @notice forfited bonus in kerosene
    uint120 public unclaimedBonus;

    /// @notice indicates whether claiming is paused
    bool public paused;

    modifier whenNotPaused() {
        require(!paused, Paused());
        _;
    }

    constructor(address _kerosene, address _dnft, address _keroseneVault, address _vaultManager) {
        kerosene = _kerosene;
        dnft = IERC721(_dnft);
        keroseneVault = _keroseneVault;
        vaultManager = IVaultManager(_vaultManager);
        _initializeOwner(msg.sender);
    }

    function name() public pure override returns (string memory) {
        return "Dyad LP Staking Rewards";
    }

    function description() public pure override returns (string memory) {
        return "Claim Kerosene rewards for staked LP tokens";
    }

    function getHookFlags() public pure override returns (uint256) {
        return 0;
    }

    function createPoolStaking(address _lpToken) external onlyOwnerOrRoles(POOL_MANAGER_ROLE) returns (address) {
        DyadLPStaking staking = new DyadLPStaking(_lpToken, address(dnft), owner());

        lpTokenToStaking[_lpToken] = address(staking);
        emit PoolStakingCreated(_lpToken, address(staking));
        return address(staking);
    }

    function setPaused(bool _paused) public onlyOwnerOrRoles(POOL_MANAGER_ROLE) {
        paused = _paused;
    }

    function setRewardRates(address[] calldata lpTokens, uint256[] calldata rewardRates)
        external
        onlyOwnerOrRoles(REWARDS_MANAGER_ROLE)
    {
        uint256 length = lpTokens.length;
        for (uint256 i; i < length; ++i) {
            address lpToken = lpTokens[i];
            uint256 rewardRate = rewardRates[i];
            uint256 oldRewardRate = lpTokenToRewardRate[lpToken];
            emit RewardRateSet(lpToken, oldRewardRate, rewardRate);
            lpTokenToRewardRate[lpToken] = rewardRate;
        }
    }

    function depositForRewards(uint256 amount) public onlyOwnerOrRoles(REWARDS_MANAGER_ROLE) {
        uint256 previousUnclaimedBonus = unclaimedBonus;
        unclaimedBonus = 0;
        if (amount < previousUnclaimedBonus) {
            kerosene.safeTransfer(msg.sender, previousUnclaimedBonus - amount);
        } else if (amount > previousUnclaimedBonus) {
            kerosene.safeTransferFrom(msg.sender, address(this), amount - previousUnclaimedBonus);
        }

        emit RewardsDeposited(amount);
    }

    function setRoot(bytes32 _merkleRoot, uint256 blockNumber) public onlyOwnerOrRoles(REWARDS_MANAGER_ROLE) {
        if (blockNumber > lastUpdateBlock) {
            revert InvalidBlockNumber();
        }
        merkleRoot = _merkleRoot;
        lastUpdateBlock = blockNumber;

        emit RootUpdated(_merkleRoot, blockNumber);
    }

    function claim(uint256 noteId, uint256 amount, bytes32[] calldata proof) public whenNotPaused returns (uint256) {
        address noteOwner = dnft.ownerOf(noteId);
        require(msg.sender == noteOwner, NotOwnerOfNote());

        _verifyProof(noteId, amount, proof);
        uint256 amountToSend = _syncClaimableAmount(noteId, amount);
        uint256 claimSubBonus = amountToSend.mulDiv(80, 100);
        uint256 unclaimed = amountToSend - claimSubBonus;
        unclaimedBonus += uint120(unclaimed);
        totalClaimed += uint128(claimSubBonus);

        kerosene.safeTransfer(noteOwner, claimSubBonus);

        emit Claimed(noteId, claimSubBonus, unclaimed);

        return claimSubBonus;
    }

    function claimToVault(uint256 noteId, uint256 amount, bytes32[] calldata proof)
        public
        whenNotPaused
        returns (uint256)
    {
        require(msg.sender == dnft.ownerOf(noteId), NotOwnerOfNote());

        _verifyProof(noteId, amount, proof);
        uint256 amountToSend = _syncClaimableAmount(noteId, amount);
        totalClaimed += uint128(amountToSend);

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

    function recoverERC20(address token) public onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        token.safeTransfer(msg.sender, amount);
    }

    function recoverERC721(address token, uint256 tokenId) public onlyOwner {
        IERC721(token).transferFrom(address(this), msg.sender, tokenId);
    }
}
