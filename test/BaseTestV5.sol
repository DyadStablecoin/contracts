// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DNft} from "../src/core/DNft.sol";
import {VaultManagerV2} from "../src/core/VaultManagerV2.sol";
import {VaultManagerV3} from "../src/core/VaultManagerV3.sol";
import {VaultManagerV4} from "../src/core/VaultManagerV4.sol";
import {VaultManagerV5} from "../src/core/VaultManagerV5.sol";
import {Vault} from "../src/core/Vault.sol";
import {Licenser} from "../src/core/Licenser.sol";
import {VaultLicenser} from "../src/core/VaultLicenser.sol";
import {Dyad} from "../src/core/Dyad.sol";
import {DyadXP} from "../src/staking/DyadXP.sol";
import {DyadXPv2} from "../src/staking/DyadXPv2.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {Parameters} from "../src/params/Parameters.sol";
import {IAggregatorV3} from "../src/interfaces/IAggregatorV3.sol";
import {KeroseneVault} from "../src/core/VaultKerosene.sol";
import {KerosineDenominator} from "../src/staking/KerosineDenominator.sol";
import {KeroseneOracleV2} from "../src/core/KeroseneOracleV2.sol";
import {KerosineManager} from "../src/core/KerosineManager.sol";
import {Kerosine} from "../src/staking/Kerosine.sol";

contract BaseTestV5 is Test, Parameters {

    address constant USER_1 = address(0x1111);
    address constant USER_2 = address(0x2222);
    address constant USER_3 = address(0x3333);

    IWETH weth = IWETH(MAINNET_WETH);

    VaultManagerV5 vaultManager;
    DNft dNft;
    Dyad dyad;
    Kerosine kerosene;
    Licenser licenser;
    KeroseneVault keroseneVault;
    KeroseneOracleV2 keroseneOracleV2;
    KerosineManager keroseneManager;
    KerosineDenominator keroseneDenominator;

    function setUp() public virtual {
        licenser = new Licenser();
        kerosene = new Kerosine();
        dyad = new Dyad(licenser);
        dNft = new DNft();
        VaultManagerV2 vaultManagerV2 = new VaultManagerV2();
        VaultManagerV3 vaultManagerV3 = new VaultManagerV3();
        VaultManagerV4 vaultManagerV4 = new VaultManagerV4();
        VaultManagerV5 vaultManagerV5 = new VaultManagerV5();
        VaultLicenser vaultLicenser = new VaultLicenser();
        
        keroseneOracleV2 = new KeroseneOracleV2();
        keroseneManager = new KerosineManager();
        keroseneDenominator = new KerosineDenominator(kerosene);

        address proxy = address(new ERC1967Proxy(
            address(vaultManagerV2),
            abi.encodeWithSignature("initialize(address,address,address)", address(dNft), address(dyad), address(vaultLicenser))
        ));

        Vault vault = new Vault(VaultManagerV2(proxy), ERC20(address(weth)), IAggregatorV3(MAINNET_WETH_ORACLE));
        keroseneVault = new KeroseneVault(VaultManagerV2(proxy), kerosene, dyad, keroseneManager, keroseneOracleV2, keroseneDenominator);

        DyadXP dyadXP = new DyadXP(proxy, address(keroseneVault), address(dNft));
        DyadXPv2 dyadXPv2 = new DyadXPv2(proxy, address(keroseneVault), address(dNft), address(dyad));

        vaultLicenser.add(address(vault), false);
        vaultLicenser.add(address(keroseneVault), true);

        VaultManagerV2(proxy).upgradeToAndCall(address(vaultManagerV3), abi.encodeWithSignature("initialize()"));
        VaultManagerV3(proxy).upgradeToAndCall(address(vaultManagerV4), abi.encodeWithSignature("initialize(address)", address(dyadXP)));
        
        dyadXP = VaultManagerV4(proxy).dyadXP();
        
        VaultManagerV5(proxy).upgradeToAndCall(address(vaultManagerV5), abi.encodeWithSignature("initialize()"));

        dyadXP.upgradeToAndCall(address(dyadXPv2), abi.encodeWithSignature("initialize()"));
        vaultManager = VaultManagerV5(proxy);

        dNft.mintInsiderNft(USER_1);
        dNft.mintInsiderNft(USER_2);
        dNft.mintInsiderNft(USER_3);
    }

    function test_initialized() public {
        // just verify that the setup is correct
        assertTrue(true);
    }
}