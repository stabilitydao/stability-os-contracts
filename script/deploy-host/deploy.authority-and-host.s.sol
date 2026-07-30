// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {AccessRolesLib} from "../../src/libs/AccessRolesLib.sol";
import {Authority} from "../../src/Authority.sol";
import {DataReader} from "../../src/DataReader.sol";
import {HostBridge} from "../../src/HostBridge.sol";
import {Host} from "../../src/Host.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IOwnable} from "../../src/interfaces/IOwnable.sol";
import {IOwnable} from "../../src/interfaces/IOwnable.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {PlasmaConstantsLib} from "../../chains/PlasmaConstantsLib.sol";
import {Script} from "forge-std/Script.sol";
import {SonicConstantsLib} from "../../chains/SonicConstantsLib.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {Variable, LibVariable} from "forge-std/LibVariable.sol";
import {HostCodec} from "../../src/HostCodec.sol";

/// @notice Deploy ProxyFactory
contract DeployAuthorityAndHost is Script {
    using LibVariable for Variable;

    uint internal constant SONIC_CHAIN_ID = 146;
    uint internal constant PLASMA_CHAIN_ID = 9745;

    // Ethereum
    bytes32 internal constant SALT_HOST_MAINNET = 0xece9ebd163ac88bd95711ee95b86f0f473593c23de779f85d0fa56d69acc4f64;
    address internal constant TARGET_HOST_MAINNET = 0xaAAAAaaaaa0E3D26D4733570F4e4584D7872dDE2;
    bytes32 internal constant SALT_HOST_BRIDGE_MAINNET =
        0xbab80f3b6e6a67bf68f4f54b18b658e98fe20d9ad8f6d8ac2698c58320b4d3de;
    address internal constant TARGET_HOST_BRIDGE_MAINNET = 0xBbBbBbBBBBE003BD773877C193D4B97aDe002cca;
    bytes32 internal constant SALT_DATA_READER_MAINNET =
        0x5c837a9ab7fc64bc2c65553a3ceafdc6ae3f78c1944602e8da989d9ec1fc28b3;
    address internal constant TARGET_DATA_READER_MAINNET = 0xddDDdDDDDd9cA61A2CA1D4997AAA79422AC7a3e9;
    bytes32 internal constant SALT_HOST_CODEC_MAINNET =
    0xd7db8ce6c8deb84a2c8439f4c98894520320ab91e284f1c0fb6ca61c95d3c98f;
    address internal constant TARGET_HOST_CODEC_MAINNET = 0xcCcCccCcCcacbe27f2bbE1886dd47f11EA2ECFE7;

    // Sonic
    bytes32 internal constant SALT_HOST_SONIC = 0x4fc6b5a468ed22ab3db705a64a0460587f5b2762d84261420525d1cef7602453;
    address internal constant TARGET_HOST_SONIC = 0xaAaAAAAAAA4eE37D78fB985d5fde1aD7fE2e4678;
    bytes32 internal constant SALT_HOST_BRIDGE_SONIC =
        0x2ea4c0df1f5488c3b1c6e67b1cb0b1d3e79b84e245400ae008d7f71080a975ea;
    address internal constant TARGET_HOST_BRIDGE_SONIC = 0xBbBbbbbBBb3B8D01c5Bcd4D7Ac23E12FAb8AbEBE;
    bytes32 internal constant SALT_DATA_READER_SONIC =
        0x0f732550eaf8c6937183b31fcaadb149cd56877936795795ec2414db03ca2e81;
    address internal constant TARGET_DATA_READER_SONIC = 0xdDDDddDdDDd9526CCf8F8f000e9FeCcf0dA67465;
    bytes32 internal constant SALT_HOST_CODEC_SONIC = 0xd727657a601dcdf7c637e4e07760c8a60348a78f9bc149bf8058b2513e94fd79;
    address internal constant TARGET_HOST_CODEC_SONIC = 0xCCCCcCCccc8508E9863480db2C6b6AF1C3d0233d;

    // Plasma
    bytes32 internal constant SALT_HOST_PLASMA = 0x3bc30268b17f189af4aded81112d055ca79bc0c3ce8979937e7a124be054cd22;
    address internal constant TARGET_HOST_PLASMA = 0xAaaaaAaAaab938Ec720771F9d56D38443EcE00eD;
    bytes32 internal constant SALT_HOST_BRIDGE_PLASMA =
        0xbc70ae657d509ea5ed1307c026eefc19bc6b3b8b8976e61ccbd44ccdea68df2f;
    address internal constant TARGET_HOST_BRIDGE_PLASMA = 0xBbbBBbbbbb11Bbe5c8682784e4A2e651A716a1c7;
    bytes32 internal constant SALT_DATA_READER_PLASMA =
        0x4dc664561a5e6defd6277f4ba1e44fbaf2988192c8c120cf6f4ef2927f4dcca9;
    address internal constant TARGET_DATA_READER_PLASMA = 0xDDDdDDdDdD17376E74842dD397D61deA22ECFA35;
    bytes32 internal constant SALT_HOST_CODEC_PLASMA = 0xf287f9e0f6e9da07ca4b62e22b4d895e597312ad0e316786d886fa585c632010;
    address internal constant TARGET_HOST_CODEC_PLASMA = 0xCcCCcCCCCc13E40A4df0134d91995CF6B7d49d1D;

    function run() external {
        // ---------------------- Read initial data
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address[4] memory hostBridgeReader = block.chainid == SONIC_CHAIN_ID
            ? [TARGET_HOST_SONIC, TARGET_HOST_BRIDGE_SONIC, TARGET_DATA_READER_SONIC, TARGET_HOST_CODEC_SONIC]
            : block.chainid == PLASMA_CHAIN_ID
                ? [TARGET_HOST_PLASMA, TARGET_HOST_BRIDGE_PLASMA, TARGET_DATA_READER_PLASMA, TARGET_HOST_CODEC_PLASMA]
                : [TARGET_HOST_MAINNET, TARGET_HOST_BRIDGE_MAINNET, TARGET_DATA_READER_MAINNET, TARGET_HOST_CODEC_MAINNET];
        bytes32[4] memory salts = block.chainid == SONIC_CHAIN_ID
            ? [SALT_HOST_SONIC, SALT_HOST_BRIDGE_SONIC, SALT_DATA_READER_SONIC, SALT_HOST_CODEC_SONIC]
            : block.chainid == PLASMA_CHAIN_ID
                ? [SALT_HOST_PLASMA, SALT_HOST_BRIDGE_PLASMA, SALT_DATA_READER_PLASMA, SALT_HOST_CODEC_PLASMA]
                : [SALT_HOST_MAINNET, SALT_HOST_BRIDGE_MAINNET, SALT_DATA_READER_MAINNET, SALT_HOST_CODEC_MAINNET];
        address endpoint = block.chainid == SONIC_CHAIN_ID
            ? SonicConstantsLib.LAYER_ZERO_V2_ENDPOINT
            : block.chainid == PLASMA_CHAIN_ID
                ? PlasmaConstantsLib.LAYER_ZERO_V2_ENDPOINT
                : 0x1a44076050125825900e736c501f859c50fE728c; // todo move Endpoint for Ethereum Mainnet to constants

        // ---------------------- Initialize
        StdConfig configDeployed = new StdConfig("./config.d.toml", true); // auto-write deployed addresses

        require(uint(configDeployed.get("PROXY_FACTORY").ty.kind) != 0, "ProxyFactory is NOT deployed on this chain");
        address proxyFactory = configDeployed.get("PROXY_FACTORY").toAddress();

        // todo require(uint(configDeployed.get("AUTHORITY").ty.kind) == 0, "Authority is deployed on this chain");

        // ---------------------- Deploy
        address _deployer = IOwnable(proxyFactory).owner();

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Deploy Authority
        Authority authority = new Authority(_deployer, hostBridgeReader[0], address(proxyFactory));

        /// @dev Allow authority to create new proxies
        IProxyFactory(proxyFactory).setWhitelisted(address(authority), true);

        /// @dev Allow host to create new proxies
        IProxyFactory(proxyFactory).setWhitelisted(address(hostBridgeReader[0]), true);

        /// @dev Deploy host
        {
            string[] memory unitIds = new string[](1);
            unitIds[0] = "core";
            IHost.HostInitPayload memory init = IHost.HostInitPayload({
                usedSymbols: new string[](0),
                hostVersion: "2026.00.00",
                daoHost: IHost.DaoHostInitParams({uid: 0, symbol: "HOST", name: "DAO Host", unitIds: unitIds})
            });
            address logic = address(new Host());

            authority.execute(
                address(proxyFactory),
                abi.encodeCall(
                    IProxyFactory.create2NewProxy,
                    (salts[0], logic, abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(init))))
                )
            );
        }

        /// @dev Allow host to deploy proxy
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(IHost.deployProxy.selector);

            IAccessManager(address(authority))
                .setTargetFunctionRole(
                    address(hostBridgeReader[0]), selectors, AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER
                );

            IAccessManager(address(authority)).grantRole(AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER, _deployer, 0);
        }

        /// @dev Deploy host bridge
        {
            address logic = address(new HostBridge(endpoint));
            address proxy = IHost(hostBridgeReader[0])
                .deployProxy(
                    salts[1],
                    logic,
                    abi.encode(
                        address(_deployer), // owner
                        address(_deployer) // delegate to setup the bridge
                    )
                );
            require(proxy == hostBridgeReader[1], "HostBridge address mismatch");
        }

        /// @dev Deploy data reader
        {
            address logic = address(new DataReader());
            address proxy = IHost(hostBridgeReader[0]).deployProxy(salts[2], logic, "");
            require(proxy == hostBridgeReader[2], "DataReader address mismatch");
        }

        /// @dev Deploy HostCodec
        {
            address logic = address(new HostCodec());
            address proxy = IHost(hostBridgeReader[0]).deployProxy(salts[3], logic, "");
            require(proxy == hostBridgeReader[3], "DataReader address mismatch");
        }

        // ---------------------- Write results
        vm.stopBroadcast();
        configDeployed.set("AUTHORITY", address(authority));
        configDeployed.set("HOST", address(hostBridgeReader[0]));
        configDeployed.set("HOST_BRIDGE", address(hostBridgeReader[1]));
        configDeployed.set("DATA_READER", address(hostBridgeReader[2]));
    }
}
