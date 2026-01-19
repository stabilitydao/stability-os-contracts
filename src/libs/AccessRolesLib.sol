// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library AccessRolesLib {
    /// @notice Access role for OS admin.
    uint64 internal constant OS_ADMIN = 1;

    /// @notice Access role to mint SEED and TGE tokens. Only OS itself should have this role
    uint64 internal constant OS_TOKEN_MINTER = 2;

    /// @notice Access role to use OS Bridge functionality. Only OS itself should have this role
    uint64 internal constant OS_BRIDGE_USER = 3;

    /// @notice OS Bridge contract
    uint64 internal constant OS_BRIDGE = 4;

    /// @notice Admin of HostProxyFactory
    uint64 internal constant HOST_PROXY_FACTORY_ADMIN = 5;

    /// @notice Deployer of HostProxyFactory (it's Host typically)
    uint64 internal constant HOST_PROXY_FACTORY_DEPLOYER = 6;

    /// @notice Allow to upgrade proxy implementations
    uint64 internal constant CONTRACTS_UPGRADER = 7;
}
