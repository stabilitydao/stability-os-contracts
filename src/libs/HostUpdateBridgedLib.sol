// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {IHostBridge} from "../interfaces/IHostBridge.sol";
import {IHost} from "../interfaces/IHost.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {EfficientHashLib} from "@solady/utils/EfficientHashLib.sol";
import {HostLib} from "./HostLib.sol";
import {HostEncodingLib} from "./HostEncodingLib.sol";

/// @notice Bridged DAO updating logic
library HostUpdateBridgedLib {
    //region ----------------------------------------- Public
    /// @dev Proposal to update bridged DAO on other chains is accepted => send payload hashes to bridged DAO hosts
    /// @param daoUid UID of the DAO to update
    /// @param actionKind Kind of the action to perform on bridged DAO hosts
    /// @param dstEids List of destination endpoint IDs to send the action to
    /// @param listPayloads List of payloads for the action to perform on dstEids-chains
    function sendBridgedAction(
        uint daoUid,
        uint16 actionKind,
        uint32[] memory dstEids,
        bytes[] memory listPayloads
    ) external {
        address bridge = HostConfigLib.getHostChainSettings().hostBridge;

        // --------------------- send payload-hashes to each bridged DAO host
        uint len = dstEids.length;
        for (uint i; i < len; i++) {
            bytes32 hash = EfficientHashLib.hash(listPayloads[i]);
            bytes memory payload = abi.encode(uint16(actionKind), daoUid, hash);
            HostCrossChainLib._sendCrossChainMessage(
                IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2, payload, bridge
            );

            emit IHost.BridgedActionSent(daoUid, actionKind, dstEids[i], hash);
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

        bytes32 payloadHash = EfficientHashLib.hash(actionPayload);
        HostLib.BridgedActionLocal storage action = $.bridgedActionHashes[payloadHash];
        HostLib.BridgedActionHeader memory header = HostLib.unpackBridgedActionHeader(action.bridgedActionHeader);
        uint storedDaoUid = action.daoUid;

        require(header.actionKind != 0, IHost.UnknownBridgedActionHash());
        require(!header.applied, IHost.BridgedActionAlreadyApplied());

        if (header.actionKind == uint16(IHost.BridgedActions.BRIDGE_DAO_1)) {
            // todo: may be the DAO is NOT registered yet at this point, we need to check daoSymbol

            // todo register and bridge the DAO

            // ensure that created DAO has expected symbol
            require(storedDaoUid == $.daoUids[daoSymbol], IHost.IncorrectDao());
        } else {
            require(storedDaoUid == daoUid, IHost.IncorrectDao());

            if (header.actionKind == uint16(IHost.BridgedActions.SET_BRIDGED_UNIT_2)) {
                // todo
            } else if (header.actionKind == uint16(IHost.BridgedActions.REMOVE_BRIDGED_UNIT_3)) {
                // todo
            } else if (header.actionKind == uint16(IHost.BridgedActions.SET_DAO_PARAMS_4)) {
                _updateDaoParams(daoUid, actionPayload);
            } else if (header.actionKind == uint16(IHost.BridgedActions.SET_SALTS_5)) {
                _updateSalts(daoUid, actionPayload);
            } else {
                revert IHost.UnknownBridgedActionKind();
            }
        }

        $.bridgedActionHashes[payloadHash].bridgedActionHeader = HostLib.packBridgedActionHeader(
            HostLib.BridgedActionHeader({
                actionKind: header.actionKind,
                applied: true // mark the bridged action as applied
            })
        );
    }

    /// @notice Ensure that all payloads can be decoded correctly for the given action kind
    function verify(uint16 actionKind, uint32[] memory dstEids, bytes[] memory listPayloads) internal pure {
        require(dstEids.length == listPayloads.length, IHost.IncorrectArrayLengths());

        uint len = dstEids.length;
        for (uint i; i < len; i++) {
            if (actionKind == uint16(IHost.BridgedActions.BRIDGE_DAO_1)) {
                // todo: ensure that at least 1 unit exist revert otherwise
            } else if (actionKind == uint16(IHost.BridgedActions.SET_BRIDGED_UNIT_2)) {
                // todo
            } else if (actionKind == uint16(IHost.BridgedActions.REMOVE_BRIDGED_UNIT_3)) {
                // todo
            } else if (actionKind == uint16(IHost.BridgedActions.SET_DAO_PARAMS_4)) {
                HostEncodingLib.decodeDaoParameters(listPayloads[i]);
            } else if (actionKind == uint16(IHost.BridgedActions.SET_SALTS_5)) {
                HostEncodingLib.decodeSalt(listPayloads[i]);
            } else if (actionKind == uint16(IHost.BridgedActions.UPDATE_CHAIN_SETTINGS_6)) {
                // todo
            } else if (actionKind == uint16(IHost.BridgedActions.BRIDGE_DAO_WITH_DEPLOYMENTS_7)) {
                // todo
            } else if (actionKind == uint16(IHost.BridgedActions.DEPLOYMENTS_8)) {
                // todo
            } else {
                revert IHost.UnknownBridgedActionKind();
            }
        }
    }

    //endregion ----------------------------------------- Public

    //region ----------------------------------------- Internal logic

    /// @dev Update DAO parameters according to action payload registered on initial chain
    function _updateDaoParams(uint daoUid, bytes calldata actionPayload) internal {
        ITokenomics.DaoParameters memory daoParameters = HostEncodingLib.decodeDaoParameters(actionPayload);
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoParameters[daoUid] = daoParameters;

        emit IHost.DaoParametersUpdated(daoUid, daoParameters);
    }

    /// @dev Update salts for bridged DAO contracts according to action payload registered on initial chain
    function _updateSalts(uint daoUid, bytes calldata actionPayload) internal {
        (uint16[] memory contractIndices, bytes32[] memory salt) = HostEncodingLib.decodeSalt(actionPayload);

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint len = salt.length;
        for (uint i; i < len; i++) {
            uint daoUidBySalt = $.daoUidBySalt[salt[i]];

            /// @dev Collision should be prevented by verification salt values.
            /// Assume here that new salt value is checked on all chains before applying
            /// New value can be applied only if it is not used yet AND it's not registered in any already validated proposals
            require(daoUidBySalt == 0 || daoUidBySalt == daoUid, IHost.SaltAlreadyUsed(salt[i]));

            $.salt[HostLib.getKey(daoUid, contractIndices[i])] = salt[i];
        }

        emit IHost.SaltUpdated(daoUid, contractIndices, salt);
    }

    //endregion ----------------------------------------- Internal logic
}
