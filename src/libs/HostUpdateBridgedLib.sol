// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {IHostBridge} from "../interfaces/IHostBridge.sol";
import {IHost} from "../interfaces/IHost.sol";
import {EfficientHashLib} from "@solady/utils/EfficientHashLib.sol";

/// @notice Bridged DAO updating logic
library HostUpdateBridgedLib {
    function updateBridgedDAO(
        uint daoUid,
        uint16 actionKind,
        uint32[] memory dstEids,
        bytes[] memory payloads
    ) external {
        address bridge = HostConfigLib.getHostChainSettings().hostBridge;

        uint len = dstEids.length;
        for (uint i; i < len; i++) {
            bytes32 hash = EfficientHashLib.hash(payloads[i]);
            bytes memory payload = abi.encode(uint16(actionKind), daoUid, hash);
            HostCrossChainLib._sendCrossChainMessage(
                IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2, payload, bridge
            );

            // todo emit
        }
    }

    function quoteUpdateBridgedDAO(
        uint daoUid,
        uint16 actionKind,
        uint32[] memory dstEids,
        bytes[] memory payloads
    ) external view returns (uint gas) {
        address bridge = HostConfigLib.getHostChainSettings().hostBridge;

        uint len = dstEids.length;
        for (uint i; i < len; i++) {
            bytes32 hash = EfficientHashLib.hash(payloads[i]);
            bytes memory payload = abi.encode(uint16(actionKind), daoUid, hash);
            gas += bridge == address(0)
                ? 0
                : IHostBridge(bridge)
                    .quoteSendMessage(dstEids[i], uint(IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2), payload);
        }

        return gas;
    }

    function applyUpdateAction(string calldata daoSymbol, bytes calldata actionPayload) external {
        // todo
    }
}
