// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BridgeTestLib} from "../../utils/BridgeTestLib.sol";
import {HostUtilsLib} from "../../utils/HostUtilsLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IBridgedActions} from "../../../src/interfaces/IBridgedActions.sol";
import {Vm} from "forge-std/Test.sol";

/// @dev Uses cases for updating DAO params via updateDAO
library UpdateDaoUsesCasesLib {
    //region ---------------------------------- Uses cases

    /// @dev Update DAO images - instantly or with validation/voting (and optional cross-chain processing)
    /// @param target Pass target.chainId = 0 to disable cross-chain processing
    function updateImages(
        Vm vm,
        address user,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        string memory symbol,
        IDAOData.DaoImages memory images
    ) internal returns (IDAOData.DaoData memory) {
        bytes memory payload = src.hostCodec.encode(images, src.hostCodec.PAYLOAD_API_VERSION());

        uint countProposalsBefore = src.host.proposalsLength(symbol);

        vm.prank(user);
        src.host.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_IMAGES_0), payload, "");

        /// @dev Make validation and/or voting if necessary
        if (countProposalsBefore != src.host.proposalsLength(symbol)) {
            _validateVerifyProposal(vm, symbol, src, target, payload);
        }

        return src.dataReader.getDAO(symbol);
    }

    function updateSocials(
        Vm vm,
        address user,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        string memory symbol,
        string[] memory socials
    ) internal returns (IDAOData.DaoData memory) {
        bytes memory payload = src.hostCodec.encode(socials, src.hostCodec.PAYLOAD_API_VERSION());

        uint countProposalsBefore = src.host.proposalsLength(symbol);

        vm.prank(user);
        src.host.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_SOCIALS_1), payload, "");

        /// @dev Make validation and/or voting if necessary
        if (countProposalsBefore != src.host.proposalsLength(symbol)) {
            _validateVerifyProposal(vm, symbol, src, target, payload);
        }

        return src.dataReader.getDAO(symbol);
    }

    function updateNaming(
        Vm vm,
        address user,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        string memory symbol,
        IDAOData.DaoNames memory data
    ) internal returns (IDAOData.DaoData memory) {
        bytes memory payload = src.hostCodec.encode(data, src.hostCodec.PAYLOAD_API_VERSION());

        uint countProposalsBefore = src.host.proposalsLength(symbol);

        vm.prank(user);
        src.host.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_NAMING_2), payload, "");

        /// @dev Make validation and/or voting if necessary
        if (countProposalsBefore != src.host.proposalsLength(symbol)) {
            _validateVerifyProposal(vm, symbol, src, target, payload);
        }

        return src.dataReader.getDAO(symbol);
    }

    function updateUnits(
        Vm vm,
        address user,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        string memory symbol,
        IDAOData.UnitDataInput[] memory units,
        IDAOData.UnitEmitData[] memory emitData
    ) internal returns (IDAOData.DaoData memory) {
        bytes[2] memory payload = [
            src.hostCodec.encode(units, src.hostCodec.PAYLOAD_API_VERSION()),
            src.hostCodec.encode(emitData, src.hostCodec.PAYLOAD_API_VERSION())
        ];

        uint countProposalsBefore = src.host.proposalsLength(symbol);

        vm.prank(user);
        src.host.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_UNITS_3), payload[0], payload[1]);

        /// @dev Make validation and/or voting if necessary
        if (countProposalsBefore != src.host.proposalsLength(symbol)) {
            _validateVerifyProposal(vm, symbol, src, target, payload[0]);
        }

        return src.dataReader.getDAO(symbol);
    }

    function updateFunding(
        Vm vm,
        address user,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        string memory symbol,
        IDAOData.Funding memory funding
    ) internal returns (IDAOData.DaoData memory) {
        bytes memory payload = src.hostCodec.encode(funding, src.hostCodec.PAYLOAD_API_VERSION());

        uint countProposalsBefore = src.host.proposalsLength(symbol);

        vm.prank(user);
        src.host.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_FUNDING_4), payload, "");

        /// @dev Make validation and/or voting if necessary
        if (countProposalsBefore != src.host.proposalsLength(symbol)) {
            _validateVerifyProposal(vm, symbol, src, target, payload);
        }

        return src.dataReader.getDAO(symbol);
    }

    function updateVesting(
        Vm vm,
        address user,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        string memory symbol,
        IDAOData.Vesting[] memory vestings
    ) internal returns (IDAOData.DaoData memory) {
        bytes memory payload = src.hostCodec.encode(vestings, src.hostCodec.PAYLOAD_API_VERSION());

        uint countProposalsBefore = src.host.proposalsLength(symbol);

        vm.prank(user);
        src.host.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_VESTING_5), payload, "");

        /// @dev Make validation and/or voting if necessary
        if (countProposalsBefore != src.host.proposalsLength(symbol)) {
            _validateVerifyProposal(vm, symbol, src, target, payload);
        }

        return src.dataReader.getDAO(symbol);
    }

    function updateDaoParameters(
        Vm vm,
        address user,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        string memory symbol,
        IBridgedActions.BridgeDaoParams memory daoParameters
    ) internal returns (IDAOData.DaoData memory) {
        bytes memory payload = src.hostCodec.encode(daoParameters, src.hostCodec.PAYLOAD_API_VERSION());

        uint countProposalsBefore = src.host.proposalsLength(symbol);

        vm.prank(user);
        src.host.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_DAO_PARAMETERS_6), payload, "");

        /// @dev Make validation and/or voting if necessary
        if (countProposalsBefore != src.host.proposalsLength(symbol)) {
            _validateVerifyProposal(vm, symbol, src, target, payload);
        }

        return src.dataReader.getDAO(symbol);
    }

    function updateSalt(
        Vm vm,
        address user,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        string memory symbol,
        uint16[] memory contractIndices,
        bytes32[] memory salt
    ) internal returns (IDAOData.DaoData memory) {
        bytes memory payload = src.hostCodec.encode(contractIndices, salt, src.hostCodec.PAYLOAD_API_VERSION());

        uint countProposalsBefore = src.host.proposalsLength(symbol);

        vm.prank(user);
        src.host.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_SALT_7), payload, "");

        /// @dev Make validation and/or voting if necessary
        if (countProposalsBefore != src.host.proposalsLength(symbol)) {
            _validateVerifyProposal(vm, symbol, src, target, payload);
        }

        return src.dataReader.getDAO(symbol);
    }

    function updateDaoChainSettings(
        Vm vm,
        address user,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        string memory symbol,
        IDAOData.DaoChainSettings memory chainSettings
    ) internal returns (IDAOData.DaoData memory) {
        bytes memory payload = src.hostCodec.encode(chainSettings, src.hostCodec.PAYLOAD_API_VERSION());

        uint countProposalsBefore = src.host.proposalsLength(symbol);

        vm.prank(user);
        src.host.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_DAO_CHAIN_SETTINGS_8), payload, "");

        /// @dev Make validation and/or voting if necessary
        if (countProposalsBefore != src.host.proposalsLength(symbol)) {
            _validateVerifyProposal(vm, symbol, src, target, payload);
        }

        return src.dataReader.getDAO(symbol);
    }

    function updateGovernanceSettings(
        Vm vm,
        address user,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        string memory symbol,
        IDAOData.GovernanceSettings memory data
    ) internal returns (IDAOData.DaoData memory) {
        bytes memory payload = src.hostCodec.encode(data, src.hostCodec.PAYLOAD_API_VERSION());

        uint countProposalsBefore = src.host.proposalsLength(symbol);

        vm.prank(user);
        src.host.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_GOVERNANCE_SETTINGS_10), payload, "");

        /// @dev Make validation and/or voting if necessary
        if (countProposalsBefore != src.host.proposalsLength(symbol)) {
            _validateVerifyProposal(vm, symbol, src, target, payload);
        }

        return src.dataReader.getDAO(symbol);
    }

    //endregion ---------------------------------- Uses cases

    //region ---------------------------------- Internal functions
    function _validateVerifyProposal(
        Vm vm,
        string memory symbol,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        bytes memory proposalPayload
    ) internal returns (bytes32 proposalId) {
        proposalId = HostUtilsLib.getLastProposalId(src.host, symbol);
        IDAOData.Proposal memory proposal = IDataReader(src.host.getChainSettings().dataReader).proposal(proposalId);

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

            if (target.chainId != 0) {
                BridgeTestLib.processCrossChainMessages(vm, vm.getRecordedLogs(), src, target);
            }
        }
    }
    //endregion ---------------------------------- Internal functions
}
