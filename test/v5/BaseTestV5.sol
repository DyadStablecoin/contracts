// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DNft} from "../../src/core/DNft.sol";
import {VaultManagerV2} from "../../src/core/VaultManagerV2.sol";
import {VaultManagerV3} from "../../src/core/VaultManagerV3.sol";
import {VaultManagerV4} from "../../src/core/VaultManagerV4.sol";
import {VaultManagerV5} from "../../src/core/VaultManagerV5.sol";
import {Vault} from "../../src/core/Vault.sol";
import {Licenser} from "../../src/core/Licenser.sol";
import {VaultLicenser} from "../../src/core/VaultLicenser.sol";
import {Dyad} from "../../src/core/Dyad.sol";
import {DyadXP} from "../../src/staking/DyadXP.sol";
import {DyadXPv2} from "../../src/staking/DyadXPv2.sol";
import {IWETH} from "../../src/interfaces/IWETH.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {Parameters} from "../../src/params/Parameters.sol";
import {IAggregatorV3} from "../../src/interfaces/IAggregatorV3.sol";
import {KeroseneVault} from "../../src/core/VaultKerosene.sol";
import {KerosineDenominator} from "../../src/staking/KerosineDenominator.sol";
import {KeroseneOracleV2} from "../../src/core/KeroseneOracleV2.sol";
import {KerosineManager} from "../../src/core/KerosineManager.sol";
import {Kerosine} from "../../src/staking/Kerosine.sol";
import {WETHGateway} from "../../src/periphery/WETHGateway.sol";

contract BaseTestV5 is Test, Parameters {
    address internal constant USER_1 = address(0x1111);
    address internal constant USER_2 = address(0x2222);
    address internal constant USER_3 = address(0x3333);

    IWETH internal weth = IWETH(MAINNET_WETH);

    VaultManagerV5 internal vaultManager;
    DNft internal dNft;
    Dyad internal dyad;
    Kerosine internal kerosene;
    Licenser internal licenser;
    KeroseneVault internal keroseneVault;
    KeroseneOracleV2 internal keroseneOracleV2;
    KerosineManager internal keroseneManager;
    KerosineDenominator internal keroseneDenominator;
    WETHGateway internal wethGateway;
    Vault internal wethVault;
    DyadXPv2 internal dyadXP;

    function setUp() public virtual {
        vm.etch(
            address(weth),
            hex"6060604052600436106100af576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806306fdde03146100b9578063095ea7b31461014757806318160ddd146101a157806323b872dd146101ca5780632e1a7d4d14610243578063313ce5671461026657806370a082311461029557806395d89b41146102e2578063a9059cbb14610370578063d0e30db0146103ca578063dd62ed3e146103d4575b6100b7610440565b005b34156100c457600080fd5b6100cc6104dd565b6040518080602001828103825283818151815260200191508051906020019080838360005b8381101561010c5780820151818401526020810190506100f1565b50505050905090810190601f1680156101395780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b341561015257600080fd5b610187600480803573ffffffffffffffffffffffffffffffffffffffff1690602001909190803590602001909190505061057b565b604051808215151515815260200191505060405180910390f35b34156101ac57600080fd5b6101b461066d565b6040518082815260200191505060405180910390f35b34156101d557600080fd5b610229600480803573ffffffffffffffffffffffffffffffffffffffff1690602001909190803573ffffffffffffffffffffffffffffffffffffffff1690602001909190803590602001909190505061068c565b604051808215151515815260200191505060405180910390f35b341561024e57600080fd5b61026460048080359060200190919050506109d9565b005b341561027157600080fd5b610279610b05565b604051808260ff1660ff16815260200191505060405180910390f35b34156102a057600080fd5b6102cc600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610b18565b6040518082815260200191505060405180910390f35b34156102ed57600080fd5b6102f5610b30565b6040518080602001828103825283818151815260200191508051906020019080838360005b8381101561033557808201518184015260208101905061031a565b50505050905090810190601f1680156103625780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b341561037b57600080fd5b6103b0600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091908035906020019091905050610bce565b604051808215151515815260200191505060405180910390f35b6103d2610440565b005b34156103df57600080fd5b61042a600480803573ffffffffffffffffffffffffffffffffffffffff1690602001909190803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610be3565b6040518082815260200191505060405180910390f35b34600360003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600082825401925050819055503373ffffffffffffffffffffffffffffffffffffffff167fe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c346040518082815260200191505060405180910390a2565b60008054600181600116156101000203166002900480601f0160208091040260200160405190810160405280929190818152602001828054600181600116156101000203166002900480156105735780601f1061054857610100808354040283529160200191610573565b820191906000526020600020905b81548152906001019060200180831161055657829003601f168201915b505050505081565b600081600460003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020819055508273ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff167f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925846040518082815260200191505060405180910390a36001905092915050565b60003073ffffffffffffffffffffffffffffffffffffffff1631905090565b600081600360008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002054101515156106dc57600080fd5b3373ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff16141580156107b457507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff600460008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205414155b156108cf5781600460008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020541015151561084457600080fd5b81600460008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600082825403925050819055505b81600360008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000206000828254039250508190555081600360008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600082825401925050819055508273ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff167fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef846040518082815260200191505060405180910390a3600190509392505050565b80600360003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205410151515610a2757600080fd5b80600360003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600082825403925050819055503373ffffffffffffffffffffffffffffffffffffffff166108fc829081150290604051600060405180830381858888f193505050501515610ab457600080fd5b3373ffffffffffffffffffffffffffffffffffffffff167f7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65826040518082815260200191505060405180910390a250565b600260009054906101000a900460ff1681565b60036020528060005260406000206000915090505481565b60018054600181600116156101000203166002900480601f016020809104026020016040519081016040528092919081815260200182805460018160011615610100020316600290048015610bc65780601f10610b9b57610100808354040283529160200191610bc6565b820191906000526020600020905b815481529060010190602001808311610ba957829003601f168201915b505050505081565b6000610bdb33848461068c565b905092915050565b60046020528160005260406000206020528060005260406000206000915091505054815600a165627a7a72305820deb4c2ccab3c2fdca32ab3f46728389c2fe2c165d5fafa07661e4e004f6c344a0029"
        );
        vm.store(address(weth), bytes32(uint256(0x02)), bytes32(uint256(18))); // decimals

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

        address proxy = address(
            new ERC1967Proxy(
                address(vaultManagerV2),
                abi.encodeWithSignature(
                    "initialize(address,address,address)", address(dNft), address(dyad), address(vaultLicenser)
                )
            )
        );

        licenser.add(proxy);

        wethVault = new Vault(VaultManagerV2(proxy), ERC20(address(weth)), IAggregatorV3(MAINNET_WETH_ORACLE));
        keroseneVault = new KeroseneVault(
            VaultManagerV2(proxy), kerosene, dyad, keroseneManager, keroseneOracleV2, keroseneDenominator
        );
        vm.etch(MAINNET_V2_KEROSENE_V2_VAULT, address(keroseneVault).code);
        keroseneVault = KeroseneVault(MAINNET_V2_KEROSENE_V2_VAULT);
        // set owner
        vm.store(address(keroseneVault), bytes32(uint256(0x00)), bytes32(uint256(uint160(address(this)))));
        keroseneManager.add(address(wethVault));
        keroseneVault.setDenominator(keroseneDenominator);

        DyadXP dxp = new DyadXP(proxy, address(keroseneVault), address(dNft));
        DyadXPv2 dyadXPv2 = new DyadXPv2(proxy, address(keroseneVault), address(dNft), address(dyad));

        vaultLicenser.add(address(wethVault), false);
        vaultLicenser.add(address(keroseneVault), true);

        VaultManagerV2(proxy).upgradeToAndCall(address(vaultManagerV3), abi.encodeWithSignature("initialize()"));
        VaultManagerV3(proxy).upgradeToAndCall(
            address(vaultManagerV4), abi.encodeWithSignature("initialize(address)", address(dxp))
        );

        dxp = VaultManagerV4(proxy).dyadXP();

        VaultManagerV5(proxy).upgradeToAndCall(address(vaultManagerV5), abi.encodeWithSignature("initialize()"));

        dxp.upgradeToAndCall(address(dyadXPv2), abi.encodeWithSignature("initialize()"));
        vaultManager = VaultManagerV5(proxy);

        wethGateway =
            new WETHGateway(address(dyad), address(dNft), address(weth), address(vaultManager), address(wethVault));

        vaultManager.authorizeSystemExtension(address(wethGateway), true);

        dNft.mintInsiderNft(USER_1);
        dNft.mintInsiderNft(USER_2);
        dNft.mintInsiderNft(USER_3);

        // dyadXP = vaultManager.dyadXP();
    }

    function _mockOracleResponse(address oracle, int256 price, uint8 decimals) public {
        vm.mockCall(oracle, abi.encodeWithSignature("decimals()"), abi.encode(decimals));
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(uint80(0), price, uint256(0), block.timestamp, uint80(0))
        );
    }
}
