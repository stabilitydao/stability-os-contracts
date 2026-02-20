// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {console, Vm} from "forge-std/Test.sol";
import {AccessRolesLib} from "../../src/libs/AccessRolesLib.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IDataReader} from "../../src/interfaces/IDataReader.sol";
import {IHostBridge} from "../../src/interfaces/IHostBridge.sol";
import {IHostCodec} from "../../src/interfaces/IHostCodec.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {AvalancheConstantsLib} from "../../chains/AvalancheConstantsLib.sol";
import {PlasmaConstantsLib} from "../../chains/PlasmaConstantsLib.sol";
import {SonicConstantsLib} from "../../chains/SonicConstantsLib.sol";
import {HostBridge} from "../../src/HostBridge.sol";
import {DataReader} from "../../src/DataReader.sol";
import {HostUtilsLib} from "./HostUtilsLib.sol";
// import {IHostCodec} from "../../src/interfaces/IHostCodec.sol";
import {HostCodec} from "../../src/HostCodec.sol";
import {EngineLib} from "../scenario/engine/EngineLib.sol";
import {LayerZeroUtils} from "../scenario/engine/LayerZeroUtils.sol";

/// @notice Auxiliary data types and utils to test STBL-bridge related functionality
library BridgeTestLib {
    /// @dev Set to 0 for immediate switch, or block number for gradual migration
    uint private constant GRACE_PERIOD = 0;

    uint32 internal constant MAX_MESSAGE_SIZE = 256;
    uint internal constant INITIAL_OS_ETHER_BALANCE = 100 ether;

    // --------------- Confirmations: send >= receive, see https://docs.layerzero.network/v2/developers/evm/configuration/dvn-executor-config

    /// @dev Minimum block confirmations to wait on Sonic
    uint64 internal constant MIN_BLOCK_CONFIRMATIONS_SEND_SONIC = 15;

    /// @dev Minimum block confirmations required on Avalanche
    uint64 internal constant MIN_BLOCK_CONFIRMATIONS_RECEIVE_TARGET = 10;

    /// @dev Minimum block confirmations to wait on Avalanche
    uint64 internal constant MIN_BLOCK_CONFIRMATIONS_SEND_TARGET = 15;

    /// @dev Minimum block confirmations required on Sonic
    uint64 internal constant MIN_BLOCK_CONFIRMATIONS_RECEIVE_SONIC = 10;

    /// @dev By default shared decimals (min decimals at all chains) is 6 for STBL
    uint internal constant SHARED_DECIMALS = 6;

    //region ------------------------------------- Chains
    function createConfigSonic(Vm vm, uint forkId, address delegator) internal returns (EngineLib.ChainConfig memory) {
        vm.selectFork(forkId);

        address multisig = SonicConstantsLib.MULTISIG;
        IHost.HostInitPayload memory emptyHostPayload;
        (IAuthority authority, IHost host) = HostUtilsLib.deployHost(vm, multisig, emptyHostPayload);

        address endpoint = SonicConstantsLib.LAYER_ZERO_V2_ENDPOINT;
        address hostBridge;
        address dataReader;
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = IHost.deployProxy.selector;
            vm.prank(multisig);
            authority.setTargetFunctionRole(address(host), selectors, AccessRolesLib.PROXY_DEPLOYER);

            vm.prank(multisig);
            authority.grantRole(AccessRolesLib.PROXY_DEPLOYER, address(this), 0);

            {
                address hostBridgeImpl = address(new HostBridge(endpoint));
                hostBridge = host.deployProxy("0x6512222222", hostBridgeImpl, abi.encode(multisig, delegator));
            }

            {
                address dataReaderImpl = address(new DataReader());
                dataReader = host.deployProxy("0x6513333333", dataReaderImpl, abi.encode(multisig, delegator));
            }
        }

        return EngineLib.ChainConfig({
            fork: forkId,
            chainId: 146,
            multisig: multisig,
            delegator: delegator,
            authority: authority,
            host: IHost(authority.HOST()),
            hostBridge: hostBridge,
            dataReader: IDataReader(dataReader),
            hostCodec: IHostCodec(host.deployProxy("0x1888888", address(new HostCodec()), "")),
            endpointId: SonicConstantsLib.LAYER_ZERO_V2_ENDPOINT_ID,
            endpoint: endpoint,
            sendLib: SonicConstantsLib.LAYER_ZERO_V2_SEND_ULN_302,
            receiveLib: SonicConstantsLib.LAYER_ZERO_V2_RECEIVE_ULN_302,
            executor: SonicConstantsLib.LAYER_ZERO_V2_EXECUTOR,
            hostValidator: address(0)
        });
    }

    function createConfigAvalanche(
        Vm vm,
        uint forkId,
        address delegator
    ) internal returns (EngineLib.ChainConfig memory) {
        vm.selectFork(forkId);
        address multisig = AvalancheConstantsLib.MULTISIG;
        IHost.HostInitPayload memory emptyHostPayload;
        (IAuthority authority, IHost host) = HostUtilsLib.deployHost(vm, multisig, emptyHostPayload);

        address endpoint = AvalancheConstantsLib.LAYER_ZERO_V2_ENDPOINT;
        address hostBridge;
        address dataReader;
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = IHost.deployProxy.selector;
            vm.prank(multisig);
            authority.setTargetFunctionRole(address(host), selectors, AccessRolesLib.PROXY_DEPLOYER);

            vm.prank(multisig);
            authority.grantRole(AccessRolesLib.PROXY_DEPLOYER, address(this), 0);

            {
                address hostBridgeImpl = address(new HostBridge(endpoint));
                hostBridge = host.deployProxy("0x65172301", hostBridgeImpl, abi.encode(multisig, delegator));
            }
            {
                address dataReaderImpl = address(new DataReader());
                dataReader = host.deployProxy("0x65144444444", dataReaderImpl, abi.encode(multisig, delegator));
            }
        }

        return EngineLib.ChainConfig({
            fork: forkId,
            chainId: 43114,
            multisig: multisig,
            delegator: delegator,
            authority: authority,
            host: IHost(authority.HOST()),
            hostBridge: hostBridge,
            dataReader: IDataReader(dataReader),
            hostCodec: IHostCodec(host.deployProxy("0x1850878", address(new HostCodec()), "")),
            endpointId: AvalancheConstantsLib.LAYER_ZERO_V2_ENDPOINT_ID,
            endpoint: AvalancheConstantsLib.LAYER_ZERO_V2_ENDPOINT,
            sendLib: AvalancheConstantsLib.LAYER_ZERO_V2_SEND_ULN_302,
            receiveLib: AvalancheConstantsLib.LAYER_ZERO_V2_RECEIVE_ULN_302,
            executor: AvalancheConstantsLib.LAYER_ZERO_V2_EXECUTOR,
            hostValidator: address(0)
        });
    }

    function createConfigPlasma(Vm vm, uint forkId, address delegator) internal returns (EngineLib.ChainConfig memory) {
        vm.selectFork(forkId);
        address multisig = PlasmaConstantsLib.MULTISIG;
        IHost.HostInitPayload memory emptyHostPayload;
        (IAuthority authority, IHost host) = HostUtilsLib.deployHost(vm, multisig, emptyHostPayload);

        address endpoint = PlasmaConstantsLib.LAYER_ZERO_V2_ENDPOINT;
        address hostBridge;
        address dataReader;
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = IHost.deployProxy.selector;
            vm.prank(multisig);
            authority.setTargetFunctionRole(address(host), selectors, AccessRolesLib.PROXY_DEPLOYER);

            vm.prank(multisig);
            authority.grantRole(AccessRolesLib.PROXY_DEPLOYER, address(this), 0);

            {
                address hostBridgeImpl = address(new HostBridge(endpoint));
                hostBridge = host.deployProxy("0x65172399", hostBridgeImpl, abi.encode(multisig, delegator));
            }
            {
                address dataReaderImpl = address(new DataReader());
                dataReader = host.deployProxy("0x651555555555", dataReaderImpl, abi.encode(multisig, delegator));
            }
        }

        return EngineLib.ChainConfig({
            fork: forkId,
            chainId: 9745,
            multisig: multisig,
            delegator: delegator,
            authority: authority,
            host: IHost(authority.HOST()),
            hostBridge: hostBridge,
            dataReader: IDataReader(dataReader),
            hostCodec: IHostCodec(host.deployProxy("0x1850878", address(new HostCodec()), "")),
            endpointId: PlasmaConstantsLib.LAYER_ZERO_V2_ENDPOINT_ID,
            endpoint: PlasmaConstantsLib.LAYER_ZERO_V2_ENDPOINT,
            sendLib: PlasmaConstantsLib.LAYER_ZERO_V2_SEND_ULN_302,
            receiveLib: PlasmaConstantsLib.LAYER_ZERO_V2_RECEIVE_ULN_302,
            executor: PlasmaConstantsLib.LAYER_ZERO_V2_EXECUTOR,
            hostValidator: address(0)
        });
    }

    //endregion ------------------------------------- Chains

    //region ------------------------------------- Setup bridges
    function setUpSonicAvalanche(
        Vm vm,
        EngineLib.ChainConfig memory sonic,
        EngineLib.ChainConfig memory avalanche
    ) internal {
        // ------------------- Set up sending chain for Sonic:Plasma
        vm.selectFork(sonic.fork);
        vm.startPrank(sonic.delegator);

        {
            address[] memory requiredDVNs = new address[](2);
            requiredDVNs[0] = SonicConstantsLib.SONIC_DVN_LAYER_ZERO_PUSH;
            requiredDVNs[1] = SonicConstantsLib.SONIC_DVN_HORIZEN_PUSH;

            _setupOAppOnChain(
                sonic,
                avalanche.endpointId,
                requiredDVNs,
                MIN_BLOCK_CONFIRMATIONS_SEND_SONIC,
                MAX_MESSAGE_SIZE,
                MIN_BLOCK_CONFIRMATIONS_RECEIVE_TARGET
            );
        }
        vm.stopPrank();

        // ------------------- Set up sending chain for Avalanche:Plasma
        vm.selectFork(avalanche.fork);
        vm.startPrank(avalanche.delegator);

        {
            address[] memory requiredDVNs = new address[](2);
            requiredDVNs[0] = AvalancheConstantsLib.AVALANCHE_DVN_HORIZON_PULL;
            requiredDVNs[1] = AvalancheConstantsLib.AVALANCHE_DVN_LAYER_ZERO_PUSH;
            //            requiredDVNs[1] = AVALANCHE_DVN_NETHERMIND_PULL;
            _setupOAppOnChain(
                avalanche,
                sonic.endpointId,
                requiredDVNs,
                MIN_BLOCK_CONFIRMATIONS_SEND_TARGET,
                MAX_MESSAGE_SIZE,
                MIN_BLOCK_CONFIRMATIONS_RECEIVE_TARGET
            );
        }

        vm.stopPrank();

        // ------------------- set peers
        LayerZeroUtils.setOsBridgePeers(vm, sonic, avalanche);
    }

    function setUpSonicPlasma(Vm vm, EngineLib.ChainConfig memory sonic, EngineLib.ChainConfig memory plasma) internal {
        // ------------------- Set up sending chain for Sonic:Plasma
        vm.selectFork(sonic.fork);
        vm.startPrank(sonic.delegator);

        {
            address[] memory requiredDVNs = new address[](1);
            requiredDVNs[0] = SonicConstantsLib.SONIC_DVN_LAYER_ZERO_PUSH;

            _setupOAppOnChain(
                sonic,
                plasma.endpointId,
                requiredDVNs,
                MIN_BLOCK_CONFIRMATIONS_SEND_SONIC,
                MAX_MESSAGE_SIZE,
                MIN_BLOCK_CONFIRMATIONS_RECEIVE_TARGET
            );
        }
        vm.stopPrank();

        // ------------------- Set up receiving chain for Sonic:Plasma
        vm.selectFork(plasma.fork);
        vm.startPrank(plasma.delegator);

        {
            address[] memory requiredDVNs = new address[](2);
            requiredDVNs[0] = PlasmaConstantsLib.PLASMA_DVN_LAYER_ZERO_PUSH;
            requiredDVNs[1] = PlasmaConstantsLib.PLASMA_DVN_NETHERMIND_PUSH;
            //        requiredDVNs[2] = PLASMA_DVN_HORIZON;

            _setupOAppOnChain(
                plasma,
                sonic.endpointId,
                requiredDVNs,
                MIN_BLOCK_CONFIRMATIONS_SEND_TARGET,
                MAX_MESSAGE_SIZE,
                MIN_BLOCK_CONFIRMATIONS_RECEIVE_TARGET
            );
        }
        vm.stopPrank();

        // ------------------- set peers
        LayerZeroUtils.setOsBridgePeers(vm, sonic, plasma);
    }

    function setUpAvalanchePlasma(
        Vm vm,
        EngineLib.ChainConfig memory avalanche,
        EngineLib.ChainConfig memory plasma
    ) internal {
        // ------------------- Set up sending chain for Avalanche:Plasma
        vm.selectFork(avalanche.fork);
        vm.startPrank(avalanche.delegator);

        {
            address[] memory requiredDVNs = new address[](1);
            requiredDVNs[0] = AvalancheConstantsLib.AVALANCHE_DVN_LAYER_ZERO_PUSH;
            //            requiredDVNs[1] = AVALANCHE_DVN_NETHERMIND_PULL;
            //            requiredDVNs[2] = AVALANCHE_DVN_HORIZON_PULL;
            _setupOAppOnChain(
                avalanche,
                plasma.endpointId,
                requiredDVNs,
                MIN_BLOCK_CONFIRMATIONS_SEND_TARGET,
                MAX_MESSAGE_SIZE,
                MIN_BLOCK_CONFIRMATIONS_RECEIVE_TARGET
            );
        }
        vm.stopPrank();

        // ------------------- Set up receiving chain for Avalanche:Plasma
        vm.selectFork(plasma.fork);
        vm.startPrank(plasma.delegator);
        {
            address[] memory requiredDVNs = new address[](1);
            requiredDVNs[0] = PlasmaConstantsLib.PLASMA_DVN_LAYER_ZERO_PUSH;
            _setupOAppOnChain(
                plasma,
                avalanche.endpointId,
                requiredDVNs,
                MIN_BLOCK_CONFIRMATIONS_SEND_TARGET,
                MAX_MESSAGE_SIZE,
                MIN_BLOCK_CONFIRMATIONS_RECEIVE_TARGET
            );
        }
        vm.stopPrank();

        // ------------------- set peers
        LayerZeroUtils.setOsBridgePeers(vm, avalanche, plasma);
    }

    function setUpAvalancheSonic(
        Vm vm,
        EngineLib.ChainConfig memory avalanche,
        EngineLib.ChainConfig memory sonic
    ) internal {
        // ------------------- Set up sending chain for Avalanche:Plasma
        vm.selectFork(avalanche.fork);
        vm.startPrank(avalanche.delegator);

        {
            address[] memory requiredDVNs = new address[](1);
            requiredDVNs[0] = AvalancheConstantsLib.AVALANCHE_DVN_LAYER_ZERO_PUSH;
            //            requiredDVNs[1] = AVALANCHE_DVN_NETHERMIND_PULL;
            //            requiredDVNs[2] = AVALANCHE_DVN_HORIZON_PULL;
            _setupOAppOnChain(
                avalanche,
                sonic.endpointId,
                requiredDVNs,
                MIN_BLOCK_CONFIRMATIONS_SEND_TARGET,
                MAX_MESSAGE_SIZE,
                MIN_BLOCK_CONFIRMATIONS_RECEIVE_TARGET
            );
        }
        vm.stopPrank();

        // ------------------- Set up receiving chain for Avalanche:Plasma
        vm.selectFork(sonic.fork);
        vm.startPrank(sonic.delegator);
        {
            address[] memory requiredDVNs = new address[](1);
            requiredDVNs[0] = SonicConstantsLib.SONIC_DVN_LAYER_ZERO_PUSH;
            _setupOAppOnChain(
                sonic,
                avalanche.endpointId,
                requiredDVNs,
                MIN_BLOCK_CONFIRMATIONS_SEND_TARGET,
                MAX_MESSAGE_SIZE,
                MIN_BLOCK_CONFIRMATIONS_RECEIVE_TARGET
            );
        }
        vm.stopPrank();

        // ------------------- set peers
        LayerZeroUtils.setOsBridgePeers(vm, avalanche, sonic);
    }

    //endregion ------------------------------------- Setup bridges

    //region ------------------------------------- Delegator
    function _setupOAppOnChain(
        EngineLib.ChainConfig memory src,
        uint32 dstEndpointId,
        address[] memory requiredDVNs,
        uint64 confirmations,
        uint32 maxMessageSize,
        uint64 receiveConfirmations
    ) internal {
        // assume here that fork and msg.sender are already correct
        bool bothWays = receiveConfirmations != 0;

        LayerZeroUtils.setupLayerZeroConfig(src, dstEndpointId, bothWays);
        LayerZeroUtils.setSendConfig(src, dstEndpointId, requiredDVNs, confirmations, maxMessageSize);
        if (bothWays) {
            LayerZeroUtils.setReceiveConfig(src, dstEndpointId, requiredDVNs, receiveConfirmations);
        }
    }

    //endregion ------------------------------------- Delegator

    function setupHostBridgeAndHostFactory(
        Vm vm,
        IHost host,
        EngineLib.ChainConfig memory chain,
        EngineLib.ChainConfig memory otherChain
    ) public {
        uint32[] memory endpoints = new uint32[](1);
        endpoints[0] = otherChain.endpointId;
        _setupHostBridgeAndHostFactory(vm, host, chain, endpoints);
    }

    function setupHostBridgeAndHostFactory(
        Vm vm,
        IHost host,
        EngineLib.ChainConfig memory chain,
        EngineLib.ChainConfig memory otherChain1,
        EngineLib.ChainConfig memory otherChain2
    ) public {
        uint32[] memory endpoints = new uint32[](2);
        endpoints[0] = otherChain1.endpointId;
        endpoints[1] = otherChain2.endpointId;
        _setupHostBridgeAndHostFactory(vm, host, chain, endpoints);
    }

    function _setupHostBridgeAndHostFactory(
        Vm vm,
        IHost host,
        EngineLib.ChainConfig memory chain,
        uint32[] memory endpoints
    ) public {
        // -------------------- put some ether on OS contract to send cross-chain messages
        vm.deal(address(host), INITIAL_OS_ETHER_BALANCE);

        // -------------------- set HostBridge inside host
        IHost.HostChainSettings memory config = host.getChainSettings();

        vm.prank(chain.multisig);
        host.setChainSettings(
            IHost.HostChainSettings({
                exchangeAsset: config.exchangeAsset,
                hostBridge: chain.hostBridge,
                timelock: 30 minutes,
                dataReader: address(chain.dataReader)
            })
        );

        // -------------------- set endpoints inside HostBridge
        vm.prank(chain.multisig);
        IHostBridge(chain.hostBridge).addEndpoint(endpoints);

        IAuthority accessManager = IAuthority(IHosted(address(host)).authority());

        // ----------------------------- Allow HOST to call OSBridge.sendMessageToAllChains
        {
            bytes4[] memory selectors = new bytes4[](2);
            selectors[0] = bytes4(IHostBridge.sendMessageToAllChains.selector);
            selectors[1] = bytes4(IHostBridge.sendMessage.selector);

            vm.prank(chain.multisig);
            accessManager.setTargetFunctionRole(chain.hostBridge, selectors, AccessRolesLib.HOST_BRIDGE_USER);

            vm.prank(chain.multisig);
            accessManager.grantRole(AccessRolesLib.HOST_BRIDGE_USER, address(host), 0);

            console.log("Grand host, bridge, accessManager", address(host), chain.hostBridge, address(accessManager));
        }

        // ----------------------------- Allow HostBridge to call Host.receiveCrossChainMessage
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(IHost.onReceiveCrossChainMessage.selector);

            vm.prank(chain.multisig);
            accessManager.setTargetFunctionRole(address(host), selectors, AccessRolesLib.HOST_BRIDGE);

            vm.prank(chain.multisig);
            accessManager.grantRole(AccessRolesLib.HOST_BRIDGE, address(chain.hostBridge), 0);
        }

        // ----------------------------- Set gas limits
        vm.prank(chain.multisig);
        IHostBridge(chain.hostBridge).setGasLimit(uint(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0), 70_000);

        vm.prank(chain.multisig);
        IHostBridge(chain.hostBridge).setGasLimit(uint(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1), 90_000);

        vm.prank(chain.multisig);
        IHostBridge(chain.hostBridge).setGasLimit(uint(IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2), 100_000);
    }

    /// @notice Empty function to exclude this test from coverage
    function test() public {}
}
