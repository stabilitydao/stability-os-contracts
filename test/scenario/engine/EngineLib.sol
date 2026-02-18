// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {StdConfig} from "forge-std/StdConfig.sol";

/// @dev Data types of Intents Engine
library EngineLib {
    struct ChainConfig {
        uint fork;

        address multisig;
        address delegator;

        address authority;
        address hostBridge;
        address hostCodec;
        address dataReader;

        uint32 endpointId;
        address endpoint;
        address sendLib;
        address receiveLib;
        address executor;
    }

    /// @dev Basis context - for deploy tests (host system is not yet deployed)
    struct BaseContext {
        StdConfig configDeployed;
        StdConfig config;

        /// @dev Chain for which config and configDeployed should be used. vm.chainId is 31337 in tests...
        uint chainId;
    }
}
