// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHost} from "../interfaces/IHost.sol";

/// @notice Storage for Host-global settings and Host-chain-related settings
library HostConfigLib {
    // keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostConfigLib.global")) - 1)) & ~bytes32(uint(0xff));
    bytes32 internal constant HOST_GLOBAL_STORAGE_LOCATION = 0; // todo

    // keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostConfigLib.chain")) - 1)) & ~bytes32(uint(0xff));
    bytes32 internal constant HOST_CHAIN_STORAGE_LOCATION = 0; // todo

    /// @custom:storage-location erc7201:stability.host-contracts.HostConfigLib.global
    struct HostGlobalStorage {
        IHost.HostSettings globalSettings;
    }

    /// @custom:storage-location erc7201:stability.host-contracts.HostConfigLib.chain
    struct HostChainStorage {
        IHost.HostChainSettings chainSettings;
    }

    function getHostGlobalSettings() internal pure returns (IHost.HostSettings storage $) {
        HostGlobalStorage storage _storage;

        //slither-disable-next-line assembly
        assembly {
            _storage.slot := HOST_GLOBAL_STORAGE_LOCATION
        }

        return _storage.globalSettings;
    }

    function getHostChainSettings() internal pure returns (IHost.HostChainSettings storage $) {
        HostChainStorage storage _storage;

        //slither-disable-next-line assembly
        assembly {
            _storage.slot := HOST_CHAIN_STORAGE_LOCATION
        }

        return _storage.chainSettings;
    }
}