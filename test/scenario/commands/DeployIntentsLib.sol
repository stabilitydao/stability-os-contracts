// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
import {HostBridge} from "../../../src/HostBridge.sol";
import {AccessRolesLib} from "../../../src/libs/AccessRolesLib.sol";
import {AuthorityAccessUtils} from "../access/AuthorityAccessUtils.sol";
import {Authority} from "../../../src/Authority.sol";
import {Host} from "../../../src/Host.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHosted} from "../../../src/interfaces/IHosted.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {IHostCodec} from "../../../src/interfaces/IHostCodec.sol";
import {HostCodec} from "../../../src/HostCodec.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";
import {DataReader} from "../../../src/DataReader.sol";
import {RestrictHostUtils} from "../access/RestrictHostUtils.sol";
import {RestrictHostBridgeUtils} from "../access/RestrictHostBridgeUtils.sol";

// import {console} from "forge-std/console.sol";

/// @dev All deploy-related intents
/// @dev All following intents don't depend on Vm, so they can be used both in scripts and tests.
library DeployIntentsLib {
    //region --------------------------------------- Intents data types
    struct IntentDeployAuthority {
        /// @dev Already deployed proxy factory
        address proxyFactory;

        /// @dev Initial admin of authority
        address initialAdmin;

        /// @dev Expected address of host to set in authority
        address host;

        /// @dev Multisig to make multisig the admin of authority
        address multisig;
    }

    struct IntentDeployHost {
        /// @dev Parameters of host initialization
        IHost.HostInitPayload init;

        /// @dev Salt for host
        bytes32 saltHost;

        /// @dev Already deployed authority
        address authority;

        /// @dev Multisig to set up access of multisig to restricted functions
        address multisig;
    }

    struct IntentDeployHostBridge {
        address signer;

        /// @dev Salt for host bridge
        bytes32 saltHostBridge;

        /// @dev Already deployed host
        address host;

        /// @dev Multisig to set up access of multisig to restricted functions
        address multisig;

        /// @dev LayerZero V2 endpoint address for the selected chain
        address endpoint;
    }

    struct IntentDeployHostCodec {
        /// @dev Already deployed authority
        address authority;

        /// @dev Salt for host codec
        bytes32 saltHostCodec;
    }

    struct IntentDeployDataReader {
        /// @dev Already deployed authority
        address authority;

        /// @dev Salt for data reader
        bytes32 saltDataReader;
    }

    //endregion --------------------------------------- Intents data types

    //region --------------------------------------- Deploy authority
    /// @dev Build intent for deploying authority
    /// @param proxyFactory Address of already deployed proxy factory
    function buildIntentDeployAuthority(
        StdConfig config,
        uint chainId,
        address proxyFactory
    ) internal view returns (IntentDeployAuthority memory dest) {
        dest = IntentDeployAuthority({
            proxyFactory: proxyFactory,
            initialAdmin: IOwnable(address(proxyFactory)).owner(),
            host: config.get(chainId, "HOST").toAddress(),
            multisig: config.get(chainId, "MULTISIG").toAddress()
        });
    }

    /// @dev Deploy authority and set up necessary permissions for it to work
    function deployAuthority(IntentDeployAuthority memory intent) internal returns (address) {
        Authority authority = new Authority(intent.initialAdmin, intent.host, intent.proxyFactory);

        // allow authority to create new proxies
        IProxyFactory(intent.proxyFactory).setWhitelisted(address(authority), true);

        // make multisig the admin of authority
        IAccessManager(address(authority)).grantRole(AccessRolesLib.DEFAULT_AUTHORITY_ADMIN, intent.multisig, 0);

        return address(authority);
    }

    //endregion --------------------------------------- Deploy authority

    //region --------------------------------------- Deploy Host
    /// @dev Build intent for deploying host
    function buildIntentDeployHost(
        StdConfig config,
        uint chainId,
        address authority,
        IHost.HostInitPayload memory init
    ) internal view returns (IntentDeployHost memory) {
        return IntentDeployHost({
            authority: authority,
            multisig: config.get(chainId, "MULTISIG").toAddress(),
            saltHost: config.get(chainId, "SALT_HOST").toBytes32(),
            init: init
        });
    }

    /// @dev Deploy host and set up necessary permissions for it to work
    function deployHost(IntentDeployHost memory intent) internal returns (address) {
        address proxyFactory = IAuthority(intent.authority).PROXY_FACTORY();
        address host = IProxyFactory(proxyFactory).predictAddress(intent.saltHost);
        require(host == IAuthority(intent.authority).HOST(), "Host address and host salt mismatch");

        /// @dev 1. Deploy host
        {
            address logic = address(new Host());

            IAccessManager(intent.authority)
                .execute(
                    address(proxyFactory),
                    abi.encodeCall(
                        IProxyFactory.create2NewProxy,
                        (
                            intent.saltHost,
                            logic,
                            abi.encodeCall(IHosted.initialize, (address(intent.authority), abi.encode(intent.init)))
                        )
                    )
                );
        }

        /// @dev 2. Allow Host to create new proxies
        IProxyFactory(proxyFactory).setWhitelisted(host, true);

        /// @dev 3. Set multisig as Host admin
        IAccessManager(intent.authority).grantRole(AccessRolesLib.DEFAULT_AUTHORITY_ADMIN, host, 0);

        /// @dev 4. Set up restricted access for multisig to manage the host
        RestrictHostUtils.setupMultisig(IAuthority(intent.authority), host, intent.multisig);

        return host;
    }

    //endregion --------------------------------------- Deploy Host

    //region --------------------------------------- Deploy host bridge
    /// @dev Build intent for deploying host bridge
    function buildIntentDeployHostBridge(
        StdConfig config,
        uint chainId,
        address signer,
        address host
    ) internal view returns (IntentDeployHostBridge memory) {
        return IntentDeployHostBridge({
            signer: signer,
            host: host,
            multisig: config.get(chainId, "MULTISIG").toAddress(),
            saltHostBridge: config.get(chainId, "SALT_HOST_BRIDGE").toBytes32(),
            endpoint: config.get(chainId, "LAYER_ZERO_V2_ENDPOINT").toAddress()
        });
    }

    /// @dev Deploy host bridge and set up necessary permissions for it to work
    function deployHostBridge(IntentDeployHostBridge memory intent) internal returns (IHostBridge) {
        IAuthority accessManager = IAuthority(IHosted(intent.host).authority());
        address proxyFactory = accessManager.PROXY_FACTORY();

        address hostBridge = IProxyFactory(proxyFactory).predictAddress(intent.saltHostBridge);

        /// @dev Deploy HostBridge
        {
            address logic = address(new HostBridge(intent.endpoint));

            IAccessManager(address(accessManager))
                .execute(
                    address(proxyFactory),
                    abi.encodeCall(
                        IProxyFactory.create2NewProxy,
                        (
                            intent.saltHostBridge,
                            logic,
                            abi.encodeCall(
                                IHosted.initialize,
                                (
                                    address(accessManager),
                                    abi.encode(
                                        address(intent.multisig), // owner
                                        address(intent.signer) // delegate to setup the bridge
                                    )
                                )
                            )
                        )
                    )
                );
        }

        // todo we can deploy HostBridge through host but it requires additional permission for deployer
        //        /// @dev 1. Deploy HostBridge
        //        address hostBridge = IHost(intent.host)
        //            .deployProxy(
        //                intent.saltHostBridge,
        //                logic,
        //                abi.encode(
        //                    address(intent.multisig), // owner
        //                    address(intent.signer) // delegate to setup the bridge
        //                )
        //            );

        // -------------------- set endpoints inside HostBridge
        //        IHostBridge(hostBridge).addEndpoint(endpoints);

        RestrictHostUtils.setupHostBridge(accessManager, intent.host, intent.multisig, address(hostBridge));
        RestrictHostBridgeUtils.setupMultisig(accessManager, hostBridge, intent.multisig);
        RestrictHostBridgeUtils.setupDeployer(accessManager, hostBridge, intent.signer);

        // @dev Set gas limits for HostBridge calls
        IHostBridge(hostBridge).setGasLimit(uint(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0), 70_000);

        IHostBridge(hostBridge).setGasLimit(uint(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1), 90_000);

        IHostBridge(hostBridge).setGasLimit(uint(IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2), 100_000);

        return IHostBridge(hostBridge);
    }

    //endregion --------------------------------------- Deploy host bridge

    //region --------------------------------------- Deploy host codec
    /// @dev Build intent for deploying host codec
    function buildIntentDeployHostCodec(
        StdConfig config,
        uint chainId,
        address authority_
    ) internal view returns (IntentDeployHostCodec memory) {
        return IntentDeployHostCodec({
            saltHostCodec: config.get(chainId, "SALT_HOST_CODEC").toBytes32(), authority: authority_
        });
    }

    /// @dev Deploy host bridge and set up necessary permissions for it to work
    function deployHostCodec(IntentDeployHostCodec memory intent) internal returns (IHostCodec) {
        IAuthority accessManager = IAuthority(intent.authority);
        address proxyFactory = accessManager.PROXY_FACTORY();

        address hostCodec = IProxyFactory(proxyFactory).predictAddress(intent.saltHostCodec);

        address logic = address(new HostCodec());

        /// @dev 1. Deploy HostCodec
        IAccessManager(address(accessManager))
            .execute(
                address(proxyFactory),
                abi.encodeCall(
                    IProxyFactory.create2NewProxy,
                    (intent.saltHostCodec, logic, abi.encodeCall(IHosted.initialize, (address(accessManager), "")))
                )
            );

        return IHostCodec(hostCodec);
    }

    //endregion --------------------------------------- Deploy host bridge

    //region --------------------------------------- Deploy data reader
    /// @dev Build intent for deploying data reader
    function buildIntentDeployDataReader(
        StdConfig config,
        uint chainId,
        address authority_
    ) internal view returns (IntentDeployDataReader memory) {
        return IntentDeployDataReader({
            saltDataReader: config.get(chainId, "SALT_DATA_READER").toBytes32(), authority: authority_
        });
    }

    /// @dev Deploy data reader and set up necessary permissions for it to work
    function deployDataReader(IntentDeployDataReader memory intent) internal returns (IDataReader) {
        IAuthority accessManager = IAuthority(intent.authority);
        address proxyFactory = accessManager.PROXY_FACTORY();

        address dataReader = IProxyFactory(proxyFactory).predictAddress(intent.saltDataReader);

        address logic = address(new DataReader());

        /// @dev 1. Deploy DataReader
        IAccessManager(address(accessManager))
            .execute(
                address(proxyFactory),
                abi.encodeCall(
                    IProxyFactory.create2NewProxy,
                    (intent.saltDataReader, logic, abi.encodeCall(IHosted.initialize, (address(accessManager), "")))
                )
            );

        return IDataReader(dataReader);
    }

    //endregion --------------------------------------- Deploy data reader
}

