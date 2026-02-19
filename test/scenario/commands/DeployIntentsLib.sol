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

// import {console} from "forge-std/console.sol";

/// @dev All deploy-related intents
library DeployIntentsLib {
    //region --------------------------------------- Intents data types
    struct IntentDeployAuthorityIn {
        /// @dev Already deployed proxy factory
        address proxyFactory;

        /// @dev Initial admin of authority
        address initialAdmin;

        /// @dev Expected address of host to set in authority
        address host;
    }

    struct IntentDeployHostIn {
        /// @dev Parameters of host initialization
        IHost.HostInitPayload init;

        /// @dev Salt for host
        bytes32 saltHost;

        /// @dev Already deployed authority
        address authority;

        /// @dev Multisig to set up access of multisig to restricted functions
        address multisig;
    }

    struct IntentDeployHostBridgeIn {
        address signer;

        /// @dev Salt for host
        bytes32 saltHostBridge;

        /// @dev Already deployed host
        address host;

        /// @dev Multisig to set up access of multisig to restricted functions
        address multisig;

        /// @dev LayerZero V2 endpoint address for the selected chain
        address endpoint;
    }

    //endregion --------------------------------------- Intents data types

    //region --------------------------------------- Deploy authority
    /// @dev Build intent for deploying authority
    /// @param proxyFactory Address of already deployed proxy factory
    function buildIntentDeployAuthority(
        StdConfig config,
        uint chainId,
        address proxyFactory
    ) internal view returns (IntentDeployAuthorityIn memory dest) {
        dest = IntentDeployAuthorityIn({
            proxyFactory: proxyFactory,
            initialAdmin: IOwnable(address(proxyFactory)).owner(),
            host: config.get(chainId, "HOST").toAddress()
        });
    }

    /// @dev Deploy authority and set up necessary permissions for it to work
    function deployAuthority(IntentDeployAuthorityIn memory intent) internal returns (address) {
        Authority authority = new Authority(intent.initialAdmin, intent.host, intent.proxyFactory);

        // allow authority to create new proxies
        IProxyFactory(intent.proxyFactory).setWhitelisted(address(authority), true);

        return address(authority);
    }

    //endregion --------------------------------------- Deploy authority

    //region --------------------------------------- Deploy Host
    /// @dev Build intent for deploying authority
    function buildIntentDeployHost(
        StdConfig config,
        uint chainId,
        address authority,
        IHost.HostInitPayload memory init
    ) internal view returns (IntentDeployHostIn memory) {
        return IntentDeployHostIn({
            authority: authority,
            multisig: config.get(chainId, "MULTISIG").toAddress(),
            saltHost: config.get(chainId, "SALT_HOST").toBytes32(),
            init: init
        });
    }

    /// @dev Deploy host and set up necessary permissions for it to work
    function deployHost(IntentDeployHostIn memory intent) internal returns (address) {
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

        /// @dev 4. Set multisig as VOTING RESULTS PROVIDER for Host
        AuthorityAccessUtils.setRestrictedAccess(
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.HOST_VOTING_RESULTS_PROVIDER,
            address(host),
            IHost.receiveVotingResults.selector
        );

        /// @dev 5. Set multisig as VALIDATOR for Host
        AuthorityAccessUtils.setRestrictedAccess(
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.HOST_VALIDATOR,
            address(host),
            IHost.receiveVotingResults.selector
        );

        /// @dev 6. allow multisig to refund and update by admin in Host
        AuthorityAccessUtils.setRestrictedAccess(
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.HOST_ADMIN,
            address(host),
            Host.updateByAdmin.selector,
            Host.refundFor.selector
        );

        /// @dev 7. allow multisig to update settings in Host
        AuthorityAccessUtils.setRestrictedAccess(
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.HOST_ADMIN,
            address(host),
            Host.setSettings.selector,
            Host.setChainSettings.selector
        );

        /// @dev 8. allow Multisig to set proxy implementations in Host
        AuthorityAccessUtils.setRestrictedAccess(
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.HOST_PROXY_FACTORY_ADMIN,
            address(host),
            IHost.setContractImplementation.selector
        );

        /// @dev 9. allow Multisig to deployProxy in Host
        AuthorityAccessUtils.setRestrictedAccess(
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.PROXY_DEPLOYER,
            address(host),
            IHost.deployProxy.selector
        );

        return host;
    }

    //endregion --------------------------------------- Deploy Host

    //region --------------------------------------- Deploy host bridge
    /// @dev Build intent for deploying authority
    function buildIntentDeployHostBridge(
        StdConfig config,
        uint chainId,
        address signer,
        address host
    ) internal view returns (IntentDeployHostBridgeIn memory) {
        return IntentDeployHostBridgeIn({
            signer: signer,
            host: host,
            multisig: config.get(chainId, "MULTISIG").toAddress(),
            saltHostBridge: config.get(chainId, "SALT_HOST_BRIDGE").toBytes32(),
            endpoint: config.get(chainId, "LAYER_ZERO_V2_ENDPOINT").toAddress()
        });
    }

    /// @dev Deploy host bridge and set up necessary permissions for it to work
    function deployHostBridge(IntentDeployHostBridgeIn memory intent) internal returns (IHostBridge) {
        IAuthority accessManager = IAuthority(IHosted(intent.host).authority());
        address proxyFactory = accessManager.PROXY_FACTORY();

        address hostBridge = IProxyFactory(proxyFactory).predictAddress(intent.saltHostBridge);

        /// @dev 1. Deploy HostBridge
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
                        abi.encodeCall(IHosted.initialize, (address(accessManager),
                        abi.encode(
                            address(intent.multisig), // owner
                            address(intent.signer) // delegate to setup the bridge
                        )
                    )))
                )
            );
        }

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

        /// @dev 2. Allow HOST to call OSBridge.sendMessageToAllChains
        AuthorityAccessUtils.setRestrictedAccess(
            accessManager,
            intent.multisig,
            AccessRolesLib.HOST_BRIDGE_USER,
            address(intent.host),
            IHostBridge.sendMessageToAllChains.selector,
            IHostBridge.sendMessage.selector
        );

        // @dev 3. Allow HostBridge to call Host.receiveCrossChainMessage
        AuthorityAccessUtils.setRestrictedAccess(
            accessManager,
            address(hostBridge),
            AccessRolesLib.HOST_BRIDGE,
            address(intent.host),
            IHost.onReceiveCrossChainMessage.selector
        );

        // @dev 4. Allow multisig to setup HostBridge
        AuthorityAccessUtils.setRestrictedAccess(
            accessManager,
            intent.multisig,
            AccessRolesLib.HOST_BRIDGE_ADMIN,
            address(hostBridge),
            IHostBridge.setGasLimit.selector,
            IHostBridge.addEndpoint.selector,
            IHostBridge.removeEndpoint.selector
        );

        // @dev 5. Allow msg.sender to setup GasLimit
        AuthorityAccessUtils.setRestrictedAccess(
            accessManager,
            intent.signer,
            AccessRolesLib.HOST_BRIDGE_ADMIN,
            address(hostBridge),
            IHostBridge.setGasLimit.selector
        );

        // @dev 5. Set gas limits for HostBridge calls
        IHostBridge(hostBridge).setGasLimit(uint(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0), 70_000);

        IHostBridge(hostBridge).setGasLimit(uint(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1), 90_000);

        IHostBridge(hostBridge).setGasLimit(uint(IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2), 100_000);

        return IHostBridge(hostBridge);
    }

    //endregion --------------------------------------- Deploy host bridge
}
