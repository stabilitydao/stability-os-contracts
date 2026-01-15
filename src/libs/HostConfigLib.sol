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
        return getHostGlobalStorage().globalSettings;
    }

    function getHostChainSettings() internal pure returns (IHost.HostChainSettings storage $) {
        return getHostChainStorage().chainSettings;
    }

    function getHostGlobalStorage() internal pure returns (HostGlobalStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := HOST_GLOBAL_STORAGE_LOCATION
        }
    }

    function getHostChainStorage() internal pure returns (HostChainStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := HOST_CHAIN_STORAGE_LOCATION
        }

    }

}