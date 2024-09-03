import {IExtension} from "../interfaces/IExtension.sol";
import {Dyad} from "../core/Dyad.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

interface ICurvePool {
    function N_COINS() external view returns (uint256);
    function add_liquidity(uint256[] calldata amounts, uint256 minMintAmount, address receiver)
        external
        returns (uint256);
    function remove_liquidity_one_coin(uint256 burnAmount, int128 i, uint256 minReceived, address receiver)
        external
        returns (uint256);
}

contract CurveZap is IExtension {
    using SafeTransferLib for ERC20;

    error NotDnftOwner();
    error OnlyVaultManager();

    IERC721 public immutable dnft;
    IVaultManager public immutable vaultManager;
    Dyad public immutable dyad;

    constructor(address _dnft, address _vaultManager, address _dyad) {
        dnft = IERC721(_dnft);
        vaultManager = IVaultManager(_vaultManager);
        dyad = Dyad(_dyad);
    }

    function name() external pure override returns (string memory) {
        return "Curve Zapper";
    }

    function description() external pure override returns (string memory) {
        return "Provides the ability to mint and repay DYAD directly into/from Curve LP tokens";
    }

    function getHookFlags() external pure override returns (uint256) {
        return 0;
    }

    function mintZap(uint256 id, uint256 dyadAmount, address pool, uint256 dyadIndex, uint256 minAmountOut, address to)
        external
        returns (uint256)
    {
        if (dnft.ownerOf(id) != msg.sender) {
            revert NotDnftOwner();
        }
        vaultManager.mintDyad(id, dyadAmount, address(this));
        dyad.approve(pool, dyadAmount);
        uint256[] memory amounts = new uint256[](ICurvePool(pool).N_COINS());
        amounts[dyadIndex] = dyadAmount;
        return ICurvePool(pool).add_liquidity(amounts, minAmountOut, to);
    }

    function repayZap(uint256 id, uint256 lpAmount, address pool, int128 dyadIndex, uint256 minAmountOut) external {
        if (dnft.ownerOf(id) != msg.sender) {
            revert NotDnftOwner();
        }

        uint256 mintedDyad = dyad.mintedDyad(id);
        ERC20(pool).safeTransferFrom(msg.sender, address(this), lpAmount);
        uint256 amountOut = ICurvePool(pool).remove_liquidity_one_coin(lpAmount, dyadIndex, minAmountOut, address(this));
        if (amountOut > mintedDyad) {
            vaultManager.burnDyad(id, mintedDyad);
            ERC20(dyad).safeTransfer(msg.sender, mintedDyad - amountOut);
        } else {
            vaultManager.burnDyad(id, amountOut);
        }
    }
}
