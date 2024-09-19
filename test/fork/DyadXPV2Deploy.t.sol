import {Test} from "forge-std/Test.sol";
import {Parameters} from "../../src/params/Parameters.sol";
import {DyadXP} from "../../src/staking/DyadXP.sol";
import {DyadXPv2} from "../../src/staking/DyadXPv2.sol";
import {VaultManagerV5} from "../../src/core/VaultManagerV5.sol";

contract DyadXPV2Deploy is Test, Parameters {
    function setUp() public {}

    function test_deploy() public {
        DyadXPv2 xp = new DyadXPv2(
            address(MAINNET_V2_VAULT_MANAGER),
            address(MAINNET_V2_KEROSENE_V2_VAULT),
            address(MAINNET_DNFT),
            address(MAINNET_V2_DYAD)
        );

        vm.prank(MAINNET_FEE_RECIPIENT);
        DyadXP(MAINNET_V2_XP).upgradeToAndCall(address(xp), abi.encodeWithSelector(xp.initialize.selector));
    }
}
