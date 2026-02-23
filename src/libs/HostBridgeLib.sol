// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {EfficientHashLib} from "@solady/utils/EfficientHashLib.sol";
import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {IBridgedActions} from "../interfaces/IBridgedActions.sol";
import {HostLib} from "./HostLib.sol";
import {HostEncodingLib} from "./HostEncodingLib.sol";

/// @notice Process "bridged actions". Such actions are registered and voted on initial chains, then their
/// payload hashes are sent to bridged DAO hosts through cross-chain messages.
/// Finally, the action is performed on bridged DAO hosts by applying the payload registered on the initial chain.
library HostBridgeLib {
    //region ----------------------------------------- Main logic
    /// @dev Proposal to update bridged DAO on other chains is accepted => send payload hashes to bridged DAO hosts
    /// @param daoUid UID of the DAO to update
    /// @param payload Payload with action details.
    function sendBridgedAction(uint daoUid, bytes memory payload, bytes32 proposalId) external {
        (uint16 actionKind, uint32[] memory dstEids, bytes[] memory actionPayloads) =
            HostEncodingLib.decodeBridgedAction(payload);
        _sendBridgedAction(daoUid, actionKind, dstEids, actionPayloads, proposalId);
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
            fee += HostCrossChainLib._quoteMessage(
                dstEids[i],
                IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2,
                HostCrossChainLib.packMessageBridgedActionHash(uint16(actionKind), daoUid, hash),
                bridge
            );
        }

        return fee;
    }

    /// @notice Apply bridged action on this chain
    /// @param actionPayload Payload with action details.
    /// Its hash should be already registered on this chain
    function applyBridgedAction(bytes32 proposalId, bytes calldata actionPayload) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        bytes32 payloadHash = _getHashProposalAction(proposalId, actionPayload);
        console.log("applyBridgedAction");
        console.logBytes32(payloadHash);
        HostLib.BridgedActionLocal storage action = $.bridgedActionHashes[payloadHash];
        HostLib.BridgedActionHeader memory header = HostLib.unpackBridgedActionHeader(action.bridgedActionHeader);
        uint daoUid = action.daoUid;

        require(header.actionKind != 0, IHost.UnknownBridgedActionHash());
        require(!header.applied, IHost.BridgedActionAlreadyApplied());

        _applyBridgedAction(daoUid, IHost.BridgedActions(header.actionKind), actionPayload);

        $.bridgedActionHashes[payloadHash].bridgedActionHeader = HostLib.packBridgedActionHeader(
            HostLib.BridgedActionHeader({
                actionKind: header.actionKind,
                applied: true // mark the bridged action as applied
            })
        );
    }

    /// @notice Ensure that all payloads can be decoded correctly for the given action kind
    function verify(
        uint daoUid,
        uint16 bridgedAction_,
        uint32[] memory dstEids,
        bytes[] memory listPayloads
    ) external view {
        require(dstEids.length == listPayloads.length, IHost.IncorrectArrayLengths());

        uint len = dstEids.length;
        for (uint i; i < len; i++) {
            if (bridgedAction_ == uint16(IHost.BridgedActions.BRIDGE_DAO_1)) {
                _verifyBridgedActionBridgeDao(daoUid, HostEncodingLib.decodeBridgeDaoParams(listPayloads[i]));
            } else if (bridgedAction_ == uint16(IHost.BridgedActions.SET_BRIDGED_UNITS_2)) {
                _verifyBridgedUnits(daoUid, HostEncodingLib.decodeBridgedUnits(listPayloads[i]));
            } else if (bridgedAction_ == uint16(IHost.BridgedActions.SET_DAO_PARAMS_4)) {
                HostEncodingLib.decodeDaoParameters(listPayloads[i]);
            } else if (bridgedAction_ == uint16(IHost.BridgedActions.SET_SALTS_5)) {
                HostEncodingLib.decodeSalt(listPayloads[i]);
            } else if (bridgedAction_ == uint16(IHost.BridgedActions.UPDATE_CHAIN_SETTINGS_6)) {
                HostEncodingLib.decodeDaoChainSettings(listPayloads[i]);
            } else if (bridgedAction_ == uint16(IHost.BridgedActions.BRIDGE_DAO_WITH_DEPLOYMENTS_7)) {
                // todo
            } else if (bridgedAction_ == uint16(IHost.BridgedActions.DEPLOYMENTS_8)) {
                // todo
            } else {
                revert IHost.UnknownBridgedActionKind();
            }
        }
    }

    //endregion ----------------------------------------- Main logic

    //region ----------------------------------------- Internal logic
    /// @dev Proposal to update bridged DAO on other chains is accepted => send payload hashes to bridged DAO hosts
    /// @param daoUid UID of the DAO to update
    /// @param bridgedActionKind Kind of the action to perform on bridged DAO hosts
    /// @param dstEids List of destination endpoint IDs to send the action to
    /// @param listPayloads List of payloads for the action to perform on dstEids-chains
    function _sendBridgedAction(
        uint daoUid,
        uint16 bridgedActionKind,
        uint32[] memory dstEids,
        bytes[] memory listPayloads,
        bytes32 proposalId
    ) internal {
        address bridge = HostConfigLib.getHostChainSettings().hostBridge;

        // --------------------- send payload-hashes to each bridged DAO host
        uint len = dstEids.length;
        for (uint i; i < len; i++) {
            bytes32 hash = _getHashProposalAction(proposalId, listPayloads[i]);
            HostCrossChainLib._sendCrossChainMessage(
                dstEids[i],
                IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2,
                HostCrossChainLib.packMessageBridgedActionHash(uint16(bridgedActionKind), daoUid, hash),
                bridge
            );

            emit IHost.BridgedActionSent(
                daoUid, uint16(IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2), dstEids[i], hash
            );
        }
    }

    /// @notice Get hash of proposal action payload. This hash is passed through cross-chain messages
    function _getHashProposalAction(bytes32 proposalId, bytes memory actionPayload) internal pure returns (bytes32) {
        return EfficientHashLib.hash(proposalId, EfficientHashLib.hash(actionPayload));
    }

    function _applyBridgedAction(uint daoUid, IHost.BridgedActions actionKind, bytes calldata actionPayload) internal {
        if (actionKind == IHost.BridgedActions.BRIDGE_DAO_1) {
            _applyBridgeDaoUpdate(daoUid, HostEncodingLib.decodeBridgeDaoParams(actionPayload));
        } else if (actionKind == IHost.BridgedActions.SET_BRIDGED_UNITS_2) {
            _applyBridgedUnits(daoUid, HostEncodingLib.decodeBridgedUnits(actionPayload));
        } else if (actionKind == IHost.BridgedActions.SET_DAO_PARAMS_4) {
            _applyDaoParametersUpdate(daoUid, HostEncodingLib.decodeDaoParameters(actionPayload));
        } else if (actionKind == IHost.BridgedActions.SET_SALTS_5) {
            (uint16[] memory contractIndices, bytes32[] memory salt) = HostEncodingLib.decodeSalt(actionPayload);
            _applySaltsUpdate(daoUid, contractIndices, salt);
        } else if (actionKind == IHost.BridgedActions.UPDATE_CHAIN_SETTINGS_6) {
            _applyDaoChainSettingsUpdate(daoUid, HostEncodingLib.decodeDaoChainSettings(actionPayload));
        } else if (actionKind == IHost.BridgedActions.BRIDGE_DAO_WITH_DEPLOYMENTS_7) {
            // todo
        } else if (actionKind == IHost.BridgedActions.DEPLOYMENTS_8) {
            // todo
        } else {
            revert IHost.UnknownBridgedActionKind();
        }
    }

    //endregion ----------------------------------------- Internal logic

    //region ----------------------------------------- Verify payload logic
    function _verifyBridgedActionBridgeDao(uint daoUid, IBridgedActions.BridgeDaoParams memory p) internal view {
        /// @dev Assume here that it's useless to bridge DAO without any units
        require(p.unitIds.length != 0, IHost.UnitsRequired());

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.DaoDataSegment2 storage segment2 = $.segment2[daoUid];

        /// @dev Action bridgeDao is intended for drafts only. Live phase requires to use BRIDGE_DAO_WITH_DEPLOYMENTS_7
        require(segment2.phase < IDAOData.LifecyclePhase.LIVE_CLIFF_6, IHost.WrongAction());

        /// @dev Ensure that user set correct DAO symbol in payload
        require(
            keccak256(bytes(p.symbol)) == keccak256(bytes(segment2.symbol))
                && keccak256(bytes(p.name)) == keccak256(bytes(segment2.name)),
            IHost.IncorrectInputData()
        );

        _checkAllUnitsRegistered($, daoUid, p.unitIds);
    }

    function _verifyBridgedUnits(uint daoUid, IBridgedActions.BridgedUnits memory p) internal view {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        _checkAllUnitsRegistered($, daoUid, p.unitIds);
    }

    function _checkAllUnitsRegistered(
        HostLib.HostStorage storage $,
        uint daoUid,
        string[] memory unitIds
    ) internal view {
        // ensure that all units are registered in segment2
        for (uint i; i < unitIds.length; i++) {
            require($.units[HostLib.getUnitKey(daoUid, unitIds[i])].daoUid == daoUid, IHost.UnitNotFound());
        }
    }

    //endregion ----------------------------------------- Verify payload logic

    //region ----------------------------------------- Apply bridged action logic

    /// @dev Bridge DAO to another chain according to action payload registered on initial chain
    /// @dev No deployment here - this version of DAO bridging is used in the case of phase-before-LIVE only
    /// @param daoUid Dao UID passed through cross-chain message
    /// @param p Unpacked payload
    function _applyBridgeDaoUpdate(uint daoUid, IBridgedActions.BridgeDaoParams memory p) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        /// @dev Dao UID stored in the chain for the given symbol
        uint chainDaoUid = $.daoUids[p.symbol]; // getDaoUidStub value is valid here, don't exclude it

        /// @dev Bridging DAO is allowed only if it is not bridged yet
        require(chainDaoUid == 0 || chainDaoUid == HostLib.getDaoUidStub(), IHost.AlreadyBridged());

        $.daoUids[p.symbol] = daoUid;

        $.segment2[daoUid] = HostLib.DaoDataSegment2({
            symbol: p.symbol,
            name: p.name,
            // Actual phase doesn't matter if it's below LIVE_CLIFF.
            // For LIVE_CLIFF, etc different bridged action is used
            phase: IDAOData.LifecyclePhase.DRAFT_0,
            unitIds: p.unitIds
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
                /// @dev Assume here that daoUidBySalt == daoUid is unreal case
                require(daoUidBySalt == 0, IHost.SaltAlreadyUsed(p.salts[i]));

                $.salt[HostLib.getKey(daoUid, p.saltContractIndices[i])] = p.salts[i];
                $.daoUidBySalt[p.salts[i]] = daoUid;
            }
        }

        emit IHost.BridgeDao(daoUid, p, p.unitIds);
    }

    /// @dev Set new list of bridged units
    function _applyBridgedUnits(uint daoUid, IBridgedActions.BridgedUnits memory p) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        $.segment2[daoUid].unitIds = p.unitIds;

        emit IHost.BridgedUnitsUpdated(daoUid, p.unitIds);
    }

    /// @dev Update DAO chain-related settings according to action payload registered on initial chain
    function _applyDaoChainSettingsUpdate(uint daoUid, IDAOData.DaoChainSettings memory p) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.chainSettings[daoUid] = p;

        emit IHost.DaoChainSettingsUpdated(daoUid, p);
    }

    /// @dev Update DAO parameters according to action payload registered on initial chain
    function _applyDaoParametersUpdate(uint daoUid, IDAOData.DaoParameters memory daoParameters) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoParameters[daoUid] = daoParameters;

        emit IHost.DaoParametersUpdated(daoUid, daoParameters);
    }

    /// @dev Update salts for bridged DAO contracts according to action payload registered on initial chain
    function _applySaltsUpdate(uint daoUid, uint16[] memory contractIndices, bytes32[] memory salts) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        uint len = salts.length;
        for (uint i; i < len; i++) {
            uint daoUidBySalt = $.daoUidBySalt[salts[i]];

            /// @dev Collision should be prevented by verification salt values.
            /// Assume here that new salt value is checked on all chains before applying
            /// New value can be applied only if it is not used yet AND it's not registered in any already validated proposals
            require(daoUidBySalt == 0 || daoUidBySalt == daoUid, IHost.SaltAlreadyUsed(salts[i]));

            $.salt[HostLib.getKey(daoUid, contractIndices[i])] = salts[i];
            $.daoUidBySalt[salts[i]] = daoUid;
        }

        emit IHost.SaltUpdated(daoUid, contractIndices, salts);
    }

    //endregion ----------------------------------------- Apply bridged action logic
}
