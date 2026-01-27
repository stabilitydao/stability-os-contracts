// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {IHostBridge} from "../interfaces/IHostBridge.sol";
import {IHost} from "../interfaces/IHost.sol";
import {EfficientHashLib} from "@solady/utils/EfficientHashLib.sol";
import {HostLib} from "./HostLib.sol";

/// @notice Bridged DAO updating logic
library HostUpdateBridgedLib {
    /// @notice Proposal to update bridged DAO on other chains is accepted => send payload hashes to bridged DAO hosts
    function sendBridgedAction(
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

    /// @notice Quote fee for sending payload hashes to bridged DAO hosts
    function quoteSendBridgedAction(
        uint daoUid,
        uint16 actionKind,
        uint32[] memory dstEids,
        bytes[] memory payloads
    ) external view returns (uint fee) {
        address bridge = HostConfigLib.getHostChainSettings().hostBridge;

        uint len = dstEids.length;
        for (uint i; i < len; i++) {
            bytes32 hash = EfficientHashLib.hash(payloads[i]);
            bytes memory payload = abi.encode(uint16(actionKind), daoUid, hash);
            fee += bridge == address(0)
                ? 0
                : IHostBridge(bridge)
                    .quoteSendMessage(dstEids[i], uint(IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2), payload);
        }

        return fee;
    }

    /// @notice Apply bridged action on this chain
    /// @param actionPayload Payload with action details.
    /// Its hash should be already registered on this chain
    function applyBridgedAction(string calldata daoSymbol, bytes calldata actionPayload) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = $.daoUids[daoSymbol];

        HostLib.BridgedActionLocal memory action = $.bridgedActionHashes[EfficientHashLib.hash(actionPayload)];
        require(action.actionKind != 0, IHost.UnknownBridgedActionHash());

        if (action.actionKind == uint16(IHost.BridgedActions.DAO_BRIDGED_1)) {
            // todo: may be the DAO is NOT registered yet at this point, we need to check daoSymbol

            // todo register and bridge the DAO

            // ensure that created DAO has expected symbol
            require(action.daoUid == $.daoUids[daoSymbol], IHost.IncorrectDao());
        } else {
            require(action.daoUid == daoUid, IHost.IncorrectDao());

            if (action.actionKind == uint16(IHost.BridgedActions.SET_BRIDGED_UNIT_2)) {
                // todo
            } else if (action.actionKind == uint16(IHost.BridgedActions.REMOVE_BRIDGED_UNIT_3)) {
                // todo
            } else if (action.actionKind == uint16(IHost.BridgedActions.SET_DAO_PARAMS_4)) {
                // todo
            } else if (action.actionKind == uint16(IHost.BridgedActions.SET_SALTS_5)) {
                // todo _updateSalts()
            } else {
                revert IHost.UnknownBridgedActionKind();
            }
        }
    }
}
