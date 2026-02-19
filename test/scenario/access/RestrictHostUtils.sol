// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {AccessRolesLib} from "../../../src/libs/AccessRolesLib.sol";
import {AuthorityAccessUtils} from "../access/AuthorityAccessUtils.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";

/// @dev Routines to set up restricted access to Host functions
library RestrictHostUtils {
    /// @dev Set up restricted access for multisig to manage the host
    function setupMultisig(IAuthority authority, address host, address multisig) internal {
        /// @dev Set multisig as VOTING RESULTS PROVIDER for Host
        AuthorityAccessUtils.setRestrictedAccess(
            authority, multisig, AccessRolesLib.HOST_VOTING_RESULTS_PROVIDER, host, IHost.receiveVotingResults.selector
        );

        /// @dev Set multisig as VALIDATOR for Host
        AuthorityAccessUtils.setRestrictedAccess(
            authority, multisig, AccessRolesLib.HOST_VALIDATOR, host, IHost.receiveVotingResults.selector
        );

        /// @dev allow multisig to refund and update by admin in Host
        AuthorityAccessUtils.setRestrictedAccess(
            authority, multisig, AccessRolesLib.HOST_ADMIN, host, IHost.updateByAdmin.selector, IHost.refundFor.selector
        );

        /// @dev allow multisig to update settings in Host
        AuthorityAccessUtils.setRestrictedAccess(
            authority,
            multisig,
            AccessRolesLib.HOST_ADMIN,
            host,
            IHost.setSettings.selector,
            IHost.setChainSettings.selector
        );

        /// @dev allow Multisig to set proxy implementations in Host
        AuthorityAccessUtils.setRestrictedAccess(
            authority, multisig, AccessRolesLib.HOST_PROXY_FACTORY_ADMIN, host, IHost.setContractImplementation.selector
        );

        /// @dev allow Multisig to deployProxy in Host
        AuthorityAccessUtils.setRestrictedAccess(
            authority, multisig, AccessRolesLib.PROXY_DEPLOYER, host, IHost.deployProxy.selector
        );
    }

    /// @dev Set up restricted access for backend-validator to validate/register voting results
    function setupValidator(IAuthority authority, address host, address validator) internal {
        /// @dev allow Validator to call validate in Host
        AuthorityAccessUtils.setRestrictedAccess(
            authority, validator, AccessRolesLib.HOST_VALIDATOR, host, IHost.validateProposal.selector
        );

        /// @dev allow Validator to be register voting results provider
        AuthorityAccessUtils.setRestrictedAccess(
            authority, validator, AccessRolesLib.HOST_VOTING_RESULTS_PROVIDER, host, IHost.receiveVotingResults.selector
        );
    }

    /// @dev Set up restricted access for HostBridge to send and receive cross-chain messages
    function setupHostBridge(IAuthority authority, address host, address multisig, address hostBridge) internal {
        /// @dev Allow HOST to call OSBridge.sendMessageToAllChains
        AuthorityAccessUtils.setRestrictedAccess(
            authority,
            multisig,
            AccessRolesLib.HOST_BRIDGE_USER,
            address(host),
            IHostBridge.sendMessageToAllChains.selector,
            IHostBridge.sendMessage.selector
        );

        // @dev Allow HostBridge to call Host.receiveCrossChainMessage
        AuthorityAccessUtils.setRestrictedAccess(
            authority,
            address(hostBridge),
            AccessRolesLib.HOST_BRIDGE,
            address(host),
            IHost.onReceiveCrossChainMessage.selector
        );
    }
}
