// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

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
}
