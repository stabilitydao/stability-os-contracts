// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {Vm} from "forge-std/Test.sol";
import {EventUtilsLib} from "../../utils/EventUtilsLib.sol";
import {HostUtilsLib} from "../../utils/HostUtilsLib.sol";
import {IBridgedActions} from "../../../src/interfaces/IBridgedActions.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";
import {BridgeTestLib} from "../../utils/BridgeTestLib.sol";

library BridgedActionsUsesCaseLib {
    //region ---------------------------------- Uses cases
    /// @dev Use case of bridging a not-host DAO from chain 1 to chain 2 using BRIDGE_DAO_1 action
    function bridgeDao(
        Vm vm,
        address user,
        string memory symbol,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        IBridgedActions.BridgeDaoParams memory data
    ) internal returns (IDAOData.DaoData memory bridgedDao) {
        /// @dev Payload for target action
        bytes memory actionPayload = src.hostCodec.encode(data, src.hostCodec.PAYLOAD_API_VERSION());

        /// @dev Payload for proposal (actions for all target chains)
        bytes memory proposalPayload =
            _createBridgedAction(vm, user, symbol, IHost.BridgedActions.BRIDGE_DAO_1, src, target, actionPayload);

        /// @dev Proposal is validated and voted successfully on chain 1
        bytes32 proposalId = _validateVerifyProposal(vm, symbol, src, target, proposalPayload);

        /// @dev User applies registered action on chain 2
        return _applyProposal(vm, user, symbol, target, proposalId, actionPayload);
    }

    function bridgeUnits(
        Vm vm,
        address user,
        string memory symbol,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        IDAOData.UnitDataInput[] memory data
    ) internal returns (IDAOData.DaoData memory bridgedDao) {
        /// @dev Payload for target action
        bytes memory actionPayload = src.hostCodec.encode(data, src.hostCodec.PAYLOAD_API_VERSION());

        /// @dev Payload for proposal (actions for all target chains)
        bytes memory proposalPayload = _createBridgedAction(
            vm, user, symbol, IHost.BridgedActions.SET_BRIDGED_UNITS_2, src, target, actionPayload
        );

        /// @dev Proposal is validated and voted successfully on chain 1
        bytes32 proposalId = _validateVerifyProposal(vm, symbol, src, target, proposalPayload);

        /// @dev User applies registered action on chain 2
        return _applyProposal(vm, user, symbol, target, proposalId, actionPayload);
    }

    function bridgeDaoParameters(
        Vm vm,
        address user,
        string memory symbol,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        IDAOData.DaoParameters memory data
    ) internal returns (IDAOData.DaoData memory bridgedDao) {
        /// @dev Payload for target action
        bytes memory actionPayload = src.hostCodec.encode(data, src.hostCodec.PAYLOAD_API_VERSION());

        /// @dev Payload for proposal (actions for all target chains)
        bytes memory proposalPayload =
            _createBridgedAction(vm, user, symbol, IHost.BridgedActions.SET_DAO_PARAMS_4, src, target, actionPayload);

        /// @dev Proposal is validated and voted successfully on chain 1
        bytes32 proposalId = _validateVerifyProposal(vm, symbol, src, target, proposalPayload);

        /// @dev User applies registered action on chain 2
        return _applyProposal(vm, user, symbol, target, proposalId, actionPayload);
    }

    function bridgeSalts(
        Vm vm,
        address user,
        string memory symbol,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        uint16[] memory contractIndices,
        bytes32[] memory salt
    ) internal returns (IDAOData.DaoData memory bridgedDao) {
        /// @dev Payload for target action
        bytes memory actionPayload = src.hostCodec.encode(contractIndices, salt, src.hostCodec.PAYLOAD_API_VERSION());

        /// @dev Payload for proposal (actions for all target chains)
        bytes memory proposalPayload =
            _createBridgedAction(vm, user, symbol, IHost.BridgedActions.SET_SALTS_5, src, target, actionPayload);

        /// @dev Proposal is validated and voted successfully on chain 1
        bytes32 proposalId = _validateVerifyProposal(vm, symbol, src, target, proposalPayload);

        /// @dev User applies registered action on chain 2
        return _applyProposal(vm, user, symbol, target, proposalId, actionPayload);
    }

    function bridgeDaoChainSettings(
        Vm vm,
        address user,
        string memory symbol,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        IDAOData.DaoChainSettings memory data
    ) internal returns (IDAOData.DaoData memory bridgedDao) {
        /// @dev Payload for target action
        bytes memory actionPayload = src.hostCodec.encode(data, src.hostCodec.PAYLOAD_API_VERSION());

        /// @dev Payload for proposal (actions for all target chains)
        bytes memory proposalPayload = _createBridgedAction(
            vm, user, symbol, IHost.BridgedActions.UPDATE_CHAIN_SETTINGS_6, src, target, actionPayload
        );

        /// @dev Proposal is validated and voted successfully on chain 1
        bytes32 proposalId = _validateVerifyProposal(vm, symbol, src, target, proposalPayload);

        /// @dev User applies registered action on chain 2
        return _applyProposal(vm, user, symbol, target, proposalId, actionPayload);
    }

    //endregion ---------------------------------- Uses cases

    //region ---------------------------------- Internal functions
    function _createBridgedAction(
        Vm vm,
        address user,
        string memory symbol,
        IHost.BridgedActions bridgedActionKind,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        bytes memory actionPayload
    ) internal returns (bytes memory proposalPayload) {
        // ----------------- User registers BRIDGE_DAO_1 action on chain 1
        uint32[] memory dstEids = new uint32[](1);
        dstEids[0] = uint32(target.endpointId);

        bytes[] memory actionPayloads = new bytes[](1);
        actionPayloads[0] = actionPayload;

        vm.selectFork(src.fork);

        // ---------------------- Create proposal to bridge dao on chain 2
        vm.recordLogs();
        vm.prank(user);
        src.host.createBridgedAction(symbol, uint16(bridgedActionKind), dstEids, actionPayloads);

        // ---------------------- Receive emitted proposal payload
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (proposalPayload,) = EventUtilsLib.extractProposalPayloadAndHash(logs);
    }

    function _validateVerifyProposal(
        Vm vm,
        string memory symbol,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        bytes memory proposalPayload
    ) internal returns (bytes32 proposalId) {
        proposalId = HostUtilsLib.getLastProposalId(src.host, symbol);
        IDAOData.Proposal memory proposal = IDataReader(src.host.getChainSettings().dataReader).proposal(proposalId);

        console.logBytes32(proposalId);

        if (proposal.validationRequired) {
            uint fee = src.host.quoteProposalAction(proposalId, proposalPayload, IHost.ValidationMethod.VALIDATION_1);

            vm.prank(src.hostValidator);
            src.host.validateProposal{value: fee}(proposalId, true, proposalPayload);
        }

        if (proposal.votingRequired) {
            uint fee = src.host.quoteProposalAction(proposalId, proposalPayload, IHost.ValidationMethod.VOTING_0);

            vm.recordLogs();

            vm.prank(src.hostValidator);
            src.host.receiveVotingResults{value: fee}(proposalId, true, proposalPayload);

            BridgeTestLib.processCrossChainMessages(vm, vm.getRecordedLogs(), src, target);
        }
    }

    function _applyProposal(
        Vm vm,
        address user,
        string memory symbol,
        EngineLib.ChainConfig memory target,
        bytes32 proposalId,
        bytes memory actionPayload
    ) internal returns (IDAOData.DaoData memory) {
        vm.selectFork(target.fork);

        vm.prank(user);
        target.host.applyBridgedAction(proposalId, actionPayload);

        return IDataReader(target.dataReader).getDAO(symbol);
    }
    //endregion ---------------------------------- Internal functions
}
