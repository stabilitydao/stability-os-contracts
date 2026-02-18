// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {Vm} from "forge-std/Test.sol";
import {Authority} from "../../../src/Authority.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {AccessRolesLib} from "../../../src/libs/AccessRolesLib.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IHosted} from "../../../src/interfaces/IHosted.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {Host} from "../../../src/Host.sol";
import {AuthorityAccessUtils} from "../access/AuthorityAccessUtils.sol";

/// @dev All deploy-related intents
library DeployIntentsLib {
    //region --------------------------------------- Intents data types
    struct IntentDeployAuthorityIn {
        address signer;

        /// @dev Already deployed proxy factory
        address proxyFactory;

        /// @dev Initial admin of authority
        address initialAdmin;

        /// @dev Expected address of host to set in authority
        address host;
    }

    struct IntentDeployHostIn {
        address signer;

        /// @dev Parameters of host initialization
        IHost.HostInitPayload init;

        /// @dev Salt for host
        bytes32 saltHost;

        /// @dev Already deployed authority
        address authority;

        /// @dev Multisig to set up access of multisig to restricted functions
        address multisig;
    }
    //endregion --------------------------------------- Intents data types

    //region --------------------------------------- Deploy authority
    /// @dev Build intent for deploying authority
    /// @param proxyFactory Address of already deployed proxy factory
    /// @param signer Address that will deploy authority and set up permissions for it (should be owner of proxy factory)
    function buildIntentDeployAuthority(address proxyFactory, address signer) internal returns (IntentDeployAuthorityIn memory dest) {
        StdConfig config = new StdConfig("./config.toml", false);

        dest = IntentDeployAuthorityIn({
            signer: signer,
            proxyFactory: proxyFactory,
            initialAdmin: IOwnable(address(proxyFactory)).owner(),
            host: config.get("HOST").toAddress()
        });
    }

    /// @dev Deploy authority and set up necessary permissions for it to work
    function deployAuthority(Vm vm, IntentDeployAuthorityIn memory intent) internal returns (address) {
        vm.prank(intent.signer);
        Authority authority = new Authority(intent.initialAdmin, intent.host, intent.proxyFactory);

        // allow authority to create new proxies
        vm.prank(intent.signer);
        IProxyFactory(intent.proxyFactory).setWhitelisted(address(authority), true);

        return address(authority);
    }
    //endregion --------------------------------------- Deploy authority

    //region --------------------------------------- Deploy Host
    /// @dev Build intent for deploying authority
    /// @param signer Address that will deploy authority and set up permissions for it (should be owner of proxy factory)
    function buildIntentDeployHost(address authority, address signer, IHost.HostInitPayload memory init) internal returns (IntentDeployHostIn memory) {
        StdConfig config = new StdConfig("./config.toml", false);

        return IntentDeployHostIn({
            signer: signer,
            authority: authority,
            multisig: config.get("MULTISIG").toAddress(),
            saltHost: config.get("SALT_HOST").toBytes32(),
            init: init
        });
    }

    /// @dev Deploy authority and set up necessary permissions for it to work
    function deployHost(Vm vm, IntentDeployHostIn memory intent) internal returns (address) {
        address proxyFactory = IAuthority(intent.authority).PROXY_FACTORY();
        address host = IProxyFactory(proxyFactory).predictAddress(intent.saltHost);
        require(
            host == IAuthority(intent.authority).HOST(),
            "Host address and host salt mismatch"
        );

        /// @dev 1. Deploy host
        {
            address logic = address(new Host());

            vm.prank(intent.signer);
            IAccessManager(intent.authority).execute(
                address(proxyFactory),
                abi.encodeCall(
                    IProxyFactory.create2NewProxy,
                    (intent.saltHost, logic, abi.encodeCall(IHosted.initialize, (address(intent.authority), abi.encode(intent.init))))
                )
            );
        }

        /// @dev 2. Allow Host to create new proxies
        vm.prank(intent.signer);
        IProxyFactory(proxyFactory).setWhitelisted(host, true);

        /// @dev 3. Set multisig as Host admin
        vm.prank(intent.signer);
        IAccessManager(intent.authority).grantRole(AccessRolesLib.DEFAULT_AUTHORITY_ADMIN, host, 0);

        /// @dev 4. Set multisig as VOTING RESULTS PROVIDER for Host
        AuthorityAccessUtils.setRestrictedAccess(
            vm,
            intent.signer,
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.HOST_VOTING_RESULTS_PROVIDER,
            address(host),
            IHost.receiveVotingResults.selector
        );

        /// @dev 5. Set multisig as VALIDATOR for Host
        AuthorityAccessUtils.setRestrictedAccess(
            vm,
            intent.signer,
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.HOST_VALIDATOR,
            address(host),
            IHost.receiveVotingResults.selector
        );

        /// @dev 6. allow multisig to refund and update by admin in Host
        AuthorityAccessUtils.setRestrictedAccess(
            vm,
            intent.signer,
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.HOST_ADMIN,
            address(host),
            Host.updateByAdmin.selector,
            Host.refundFor.selector
        );

        /// @dev 7. allow multisig to update settings in Host
        AuthorityAccessUtils.setRestrictedAccess(
            vm,
            intent.signer,
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.HOST_ADMIN,
            address(host),
            Host.setSettings.selector,
            Host.setChainSettings.selector
        );

        /// @dev 8. allow Multisig to set proxy implementations in Host
        AuthorityAccessUtils.setRestrictedAccess(
            vm,
            intent.signer,
            IAuthority(intent.authority),
            intent.multisig,
            AccessRolesLib.HOST_PROXY_FACTORY_ADMIN,
            address(host),
            IHost.setContractImplementation.selector
        );

        return host;
    }
    //endregion --------------------------------------- Deploy Host

}