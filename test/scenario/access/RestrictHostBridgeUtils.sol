// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {AccessRolesLib} from "../../../src/libs/AccessRolesLib.sol";
import {AuthorityAccessUtils} from "../access/AuthorityAccessUtils.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";

/// @dev Routines to set up restricted access to HostBridge functions
library RestrictHostBridgeUtils {

    /// @dev Set up restricted access for multisig to manage the host bridge
    function setupMultisig(IAuthority authority, address hostBridge, address multisig) internal {
        // @dev Allow multisig to setup HostBridge
        AuthorityAccessUtils.setRestrictedAccess(
            authority,
            multisig,
            AccessRolesLib.HOST_BRIDGE_ADMIN,
            address(hostBridge),
            IHostBridge.setGasLimit.selector,
            IHostBridge.addEndpoint.selector,
            IHostBridge.removeEndpoint.selector
        );
    }

    /// @dev Set up restricted access for multisig to manage the host bridge
    function setupDeployer(IAuthority authority, address hostBridge, address deployer) internal {
        // @dev Allow deployer to set gas values
        AuthorityAccessUtils.setRestrictedAccess(
            authority, deployer, AccessRolesLib.HOST_BRIDGE_ADMIN, address(hostBridge), IHostBridge.setGasLimit.selector
        );
    }
}
