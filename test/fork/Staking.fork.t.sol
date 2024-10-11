// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {DyadLPStakingFactory} from "../../src/staking/DyadLPStakingFactory.sol";
import {DyadLPStaking} from "../../src/staking/DyadLPStaking.sol";
import {Parameters} from "../../src/params/Parameters.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

contract StakingTest is Test, Parameters {
    DyadLPStakingFactory public factory;

    IERC20 wM = IERC20(0x437cc33344a0B27A429f795ff6B469C72698B291);

    IERC20 dyad = IERC20(MAINNET_V2_DYAD);

    address USER_1 = address(0xabab);
    // Smart M / DYAD
    address pool = 0xa969cFCd9e583edb8c8B270Dc8CaFB33d6Cf662D;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL"), 20938966);

        factory = new DyadLPStakingFactory(
            MAINNET_KEROSENE, MAINNET_DNFT, MAINNET_V2_KEROSENE_V2_VAULT, MAINNET_V2_VAULT_MANAGER
        );

        address note0holder = IERC721(MAINNET_DNFT).ownerOf(0);
        vm.prank(note0holder);
        IERC721(MAINNET_DNFT).transferFrom(note0holder, USER_1, 0);
    }

    function test_ownerShouldBeDeployer() public {
        assertEq(factory.owner(), address(this));
    }

    function test_create() public {
        address poolStaking = factory.createPoolStaking(pool);
        assertEq(DyadLPStaking(poolStaking).owner(), address(this));
        assertEq(DyadLPStaking(poolStaking).lpToken(), pool);
        assertEq(address(DyadLPStaking(poolStaking).dnft()), MAINNET_DNFT);
        assertEq(DyadLPStaking(poolStaking).totalLP(), 0);
        assertEq(DyadLPStaking(poolStaking).name(), "Smart M / DYAD LP Staking");
    }

    function test_stakeTokens() public {
        _yoinkTokens(USER_1);

        address poolStaking = factory.createPoolStaking(pool);
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenAmounts[0] = 100000000000;
        tokenAmounts[1] = 100000 ether;

        vm.startPrank(USER_1);
        wM.approve(pool, type(uint256).max);
        dyad.approve(pool, type(uint256).max);

        (bool success, bytes memory returnData) =
            pool.call(abi.encodeWithSignature("add_liquidity(uint256[],uint256)", tokenAmounts, 0));

        assertTrue(success);
        uint256 lpAmount = abi.decode(returnData, (uint256));
        assertGt(lpAmount, 0);
        IERC20 lp = IERC20(pool);
        lp.approve(poolStaking, lpAmount);
        DyadLPStaking(poolStaking).deposit(0, lpAmount);

        vm.stopPrank();
    }

    function _yoinkTokens(address to) internal {
        vm.prank(0x6AaA90D689942b5eaB3D8433f2E02B32a0214390); // vM holder, 362k tokens
        wM.transfer(to, 100000000000);

        vm.prank(0x0698Fa3B48313c5160619bDB970dEB98e558Ea75); // dyad holder, 282k tokens
        dyad.transfer(to, 100000 ether);
    }
}
