// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IHostCodec} from "../../../src/interfaces/IHostCodec.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";
import {StdConfig} from "forge-std/StdConfig.sol";

/// @dev Data types of Intents Engine
library EngineLib {
    struct ChainConfig {
        uint fork;
        uint chainId;

        address multisig;
        address delegator;

        IAuthority authority;
        IHost host;
        address hostBridge;
        IHostCodec hostCodec;
        IDataReader dataReader;

        uint32 endpointId;
        address endpoint;
        address sendLib;
        address receiveLib;
        address executor;

        address hostValidator;
    }

    /// @dev Basis context - for deploy tests (host system is not yet deployed)
    struct BaseContext {
        StdConfig configDeployed;
        StdConfig config;

        /// @dev Chain for which config and configDeployed should be used. vm.chainId is 31337 in tests...
        uint chainId;

        uint forkId;
    }

    struct Context {
        ChainConfig core;
        BaseContext bc;
        address user;
    }

    struct Funder {
        address user;
        uint amount;
    }

}
