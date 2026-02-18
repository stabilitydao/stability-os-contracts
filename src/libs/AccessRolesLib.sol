// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library AccessRolesLib {
    uint64 internal constant DEFAULT_AUTHORITY_ADMIN = 0;

    /// @notice Access role for OS admin.
    uint64 internal constant HOST_ADMIN = 1;

    /// @notice Access role to mint SEED and TGE tokens. Only Host itself should have this role
    uint64 internal constant HOST_TOKEN_MINTER = 2;

    /// @notice Access role to use OS Bridge functionality. Only Host itself should have this role
    uint64 internal constant HOST_BRIDGE_USER = 3;

    /// @notice OS Bridge contract
    uint64 internal constant HOST_BRIDGE = 4;

    /// @notice Admin of HostProxyFactory
    uint64 internal constant HOST_PROXY_FACTORY_ADMIN = 5;

    /// @notice Deployer of HostProxyFactory (it's Host typically)
    uint64 internal constant HOST_PROXY_FACTORY_DEPLOYER = 6;

    /// @notice Allow to upgrade proxy implementations (it's Host typically)
    uint64 internal constant CONTRACTS_UPGRADER = 7;

    /// @notice Allow to deploy proxy using fabrics
    uint64 internal constant PROXY_DEPLOYER = 8;

    /// @notice Allow to call upgrade-related functions on Host
    uint64 internal constant HOST_UPGRADER = 9;

    /// @notice Allow to validate proposals
    uint64 internal constant HOST_VALIDATOR = 10;

    /// @notice Allow to register voting results
    uint64 internal constant HOST_VOTING_RESULTS_PROVIDER = 11;
}
