// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {IHostBridge} from "../interfaces/IHostBridge.sol";
import {IHost} from "../interfaces/IHost.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IBridgedActions} from "../interfaces/IBridgedActions.sol";
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
            } else if (header.actionKind == uint16(IHost.BridgedActions.UPDATE_CHAIN_SETTINGS_6)) {
                _updateDaoChainSettings(daoUid, actionPayload);
            } else if (header.actionKind == uint16(IHost.BridgedActions.BRIDGE_DAO_WITH_DEPLOYMENTS_7)) {
                // todo
            } else if (header.actionKind == uint16(IHost.BridgedActions.DEPLOYMENTS_8)) {
                // todo
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
    function verify(uint daoUid, uint16 actionKind, uint32[] memory dstEids, bytes[] memory listPayloads) external view {
        require(dstEids.length == listPayloads.length, IHost.IncorrectArrayLengths());

        uint len = dstEids.length;
        for (uint i; i < len; i++) {
            if (actionKind == uint16(IHost.BridgedActions.BRIDGE_DAO_1)) {
                IBridgedActions.BridgeDaoParams memory p = HostEncodingLib.decodeBridgeDaoParams(listPayloads[i]);
                /// @dev Assume here that it's useless to bridge DAO without any units
                require(p.unitIds.length != 0, IHost.UnitsRequired());

                HostLib.HostStorage storage $ = HostLib.getHostStorage();
                /// @dev Action bridgeDao is intended for drafts only. Live phase requires to use BRIDGE_DAO_WITH_DEPLOYMENTS_7
                require($.segment2[daoUid].phase < ITokenomics.LifecyclePhase.LIVE_CLIFF_5, IHost.WrongAction());
            } else if (actionKind == uint16(IHost.BridgedActions.SET_BRIDGED_UNIT_2)) {
                // todo
            } else if (actionKind == uint16(IHost.BridgedActions.REMOVE_BRIDGED_UNIT_3)) {
                // todo
            } else if (actionKind == uint16(IHost.BridgedActions.SET_DAO_PARAMS_4)) {
                HostEncodingLib.decodeDaoParameters(listPayloads[i]);
            } else if (actionKind == uint16(IHost.BridgedActions.SET_SALTS_5)) {
                HostEncodingLib.decodeSalt(listPayloads[i]);
            } else if (actionKind == uint16(IHost.BridgedActions.UPDATE_CHAIN_SETTINGS_6)) {
                HostEncodingLib.decodeDaoChainSettings(listPayloads[i]);
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
    /// @dev Bridge DAO to another chain according to action payload registered on initial chain
    /// @dev No deployment here - this version of DAO bridging is used in the case of phase-before-LIVE only
    function bridgeDao(uint daoUid, bytes calldata actionPayload) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        IBridgedActions.BridgeDaoParams memory p = HostEncodingLib.decodeBridgeDaoParams(actionPayload);

        bytes32[] memory hashUnitIds = new bytes32[](p.unitIds.length);
        for (uint i; i < p.unitIds.length; i++) {
            hashUnitIds[i] = HostLib.getUnitKey(daoUid, p.unitIds[i]);
        }

        $.daoUids[p.symbol] = daoUid;
        $.segment2[daoUid] = HostLib.DaoDataSegment2({
            daoSymbol: p.symbol,
            name: p.name,
            phase: ITokenomics.LifecyclePhase.DRAFT_0,
            hashUnitIds: hashUnitIds
        });

        $.daoParameters[daoUid] = p.daoParameters;
        $.chainSettings[daoUid] = p.chainSettings;

        uint len = p.saltContractIndices.length;
        if (len != 0) {
            for (uint i; i < len; i++) {
                uint daoUidBySalt = $.daoUidBySalt[p.salts[i]];

                /// @dev Collision should be prevented by verification salt values.
                /// Assume here that new salt value is checked on all chains before applying
                /// New value can be applied only if it is not used yet AND it's not registered in any already validated proposals
                require(daoUidBySalt == 0, IHost.SaltAlreadyUsed(p.salts[i]));

                $.salt[HostLib.getKey(daoUid, p.saltContractIndices[i])] = p.salts[i];
            }
        }

        emit IHost.BridgeDao(daoUid, p, hashUnitIds);
    }

    /// @dev Update DAO chain-related settings according to action payload registered on initial chain
    function _updateDaoChainSettings(uint daoUid, bytes calldata actionPayload) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.DaoChainSettings memory p = HostEncodingLib.decodeDaoChainSettings(actionPayload);
        $.chainSettings[daoUid] = p;

        emit IHost.DaoChainSettingsUpdated(daoUid, p);
    }

    /// @dev Update DAO parameters according to action payload registered on initial chain
    function _updateDaoParams(uint daoUid, bytes calldata actionPayload) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.DaoParameters memory daoParameters = HostEncodingLib.decodeDaoParameters(actionPayload);
        $.daoParameters[daoUid] = daoParameters;

        emit IHost.DaoParametersUpdated(daoUid, daoParameters);
    }

    /// @dev Update salts for bridged DAO contracts according to action payload registered on initial chain
    function _updateSalts(uint daoUid, bytes calldata actionPayload) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        (uint16[] memory contractIndices, bytes32[] memory salt) = HostEncodingLib.decodeSalt(actionPayload);

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
