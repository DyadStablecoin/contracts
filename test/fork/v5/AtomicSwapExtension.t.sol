import {AtomicSwapExtension} from "../../../src/periphery/AtomicSwapExtension.sol";
import {Test} from "forge-std/Test.sol";
import {Parameters} from "../../../src/params/Parameters.sol";
import {DNft} from "../../../src/core/DNft.sol";
import {VaultManagerV5} from "../../../src/core/VaultManagerV5.sol";

contract AtomicSwapExtensionTest is Test, Parameters {
    AtomicSwapExtension public atomicSwapExtension;

    address public USER = 0xd0953aC488190BbD59240E0A59F697e32e303532;

    function setUp() public {
        atomicSwapExtension = new AtomicSwapExtension(MAINNET_V2_VAULT_MANAGER);
        VaultManagerV5 vaultManager = VaultManagerV5(MAINNET_V2_VAULT_MANAGER);

        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 20917569);

        vaultManager = VaultManagerV5(MAINNET_V2_VAULT_MANAGER);
        VaultManagerV5 vaultManagerImpl = new VaultManagerV5();
        vm.startPrank(vaultManager.owner());
        vaultManager.upgradeToAndCall(address(vaultManagerImpl), abi.encodeWithSignature("initialize()"));
        vaultManager.authorizeSystemExtension(address(atomicSwapExtension), true);
        vm.stopPrank();

        vm.prank(USER);
        vaultManager.authorizeExtension(address(atomicSwapExtension), true);
    }

    function test_swap() public {
        vm.prank(USER);
        atomicSwapExtension.swapCollateral(
            467,
            MAINNET_V2_TBTC_VAULT,
            5e17,
            MAINNET_V2_WETH_VAULT,
            12.5 ether,
            hex"876a02f60000000000000000000000000000000000000000000000000000000000000060d0953ac488190bbd59240e0a59f697e32e303532180000000000000000000064000000000000000000000000000000000000000000000000000000000000024000000000000000000000000018084fba666a33d37592fa2633fd49a74dd93a88000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000006f05b59d3b20000000000000000000000000000000000000000000000000000b027d9687f9faf1c000000000000000000000000000000000000000000000000b1ef5ce5acdf5b8b195829a8535e440b8031f5717ee871eb000000000000000000000000013f2d380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000c080000000000000000000000018084fba666a33d37592fa2633fd49a74dd93a880000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c59900000000000000000000000000000000000000000000000000000000000000648000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c599000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000000000"
        );
    }
}
