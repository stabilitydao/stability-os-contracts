// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostBridgeLib} from "./HostBridgeLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {HostEncodingLib} from "./HostEncodingLib.sol";
import {HostLib} from "./HostLib.sol";
import {HostUpdateLib} from "./HostUpdateLib.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {IHost} from "../interfaces/IHost.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";

/// @notice Library with proposal related functions
library HostProposalsLib {
    /// @dev Initial data that is detected before update for given DAO
    struct InitData {
        uint daoUid;
        /// @dev True if instant update is possible
        bool instant;
        /// @dev Current phase of the DAO
        ITokenomics.LifecyclePhase phase;
    }

    /// @notice Receive voting results from voting module and execute proposal if approved
    /// @param proposalId Proposal unique id
    /// @param succeed True if proposal is approved
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if proposal was rejected.
    function receiveVotingResults(bytes32 proposalId, bool succeed, bytes memory payload) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.ProposalLocal storage p = $.proposals[proposalId];
        HostLib.ProposalHeader memory header = HostLib.unpackProposalHeader(p.proposalHeader);

        require(p.daoUid != 0, IHost.IncorrectProposal());
        require(header.status == ITokenomics.VotingStatus.VOTING_0, IHost.AlreadyReceived());

        /// @dev Only proposals that require a voting can receive voting results
        require(header.votingRequired, IHost.VotingNotRequired());

        /// @dev Only validated proposals or proposal that do not require validation can receive voting results
        require(
            !header.validationRequired || header.validationStatus == ITokenomics.ValidationStatus.APPROVED_1,
            IHost.ProposalNotValidated()
        );

        header.status = succeed ? ITokenomics.VotingStatus.APPROVED_1 : ITokenomics.VotingStatus.REJECTED_2;
        p.proposalHeader = HostLib.packProposalHeader(header);

        if (succeed) {
            /// @dev Ensure that provided payload is equal to the original one
            require(p.payloadHash == HostUpdateLib.getPayloadHash(payload), IHost.IncorrectProposalPayload());

            _doAction(p.daoUid, header.action, payload, p.id);
        }
    }

    /// @notice Quote gas cost to process voting results from governance
    /// @param proposalId Proposal unique id
    /// @param succeed True if proposal is approved
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if proposal was rejected.
    /// @return fee Estimated fee (in native token) to process the voting results
    function quoteReceiveVotingResults(
        bytes32 proposalId,
        bool succeed,
        bytes memory payload
    ) external view returns (uint fee) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.ProposalLocal storage p = $.proposals[proposalId];

        if (succeed) {
            HostLib.ProposalHeader memory header = HostLib.unpackProposalHeader(p.proposalHeader);
            ITokenomics.DAOAction action = header.action;
            if (action == ITokenomics.DAOAction.UPDATE_BRIDGED_DAO_9) {
                (uint16 actionKind, uint32[] memory dstEids, bytes[] memory actionPayloads) =
                    HostEncodingLib.decodeBridgedAction(payload);
                fee = HostBridgeLib.quoteSendBridgedAction(p.daoUid, actionKind, dstEids, actionPayloads);
            } else {
                // todo not-bridged actions with cross-chain messages
            }
        }

        return fee;
    }

    /// @notice Approve or reject given proposal.
    /// @param proposalId Proposal unique id
    /// @param valid True to approve, false to reject
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if the proposal requires voting or is rejected.
    function validateProposal(bytes32 proposalId, bool valid, bytes memory payload) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.ProposalLocal storage p = $.proposals[proposalId];
        HostLib.ProposalHeader memory header = HostLib.unpackProposalHeader(p.proposalHeader);

        require(p.daoUid != 0, IHost.IncorrectProposal());

        /// @dev Only proposals that require a validation can be validated.
        require(header.validationRequired, IHost.ValidationNotRequired());

        /// @dev Any proposal can be validated only once. Re-validation is not allowed to simplify uses cases
        require(header.validationStatus == ITokenomics.ValidationStatus.NONE_0, IHost.AlreadyValidated());

        /// @dev Rejected proposals are automatically get rejected-status, no voting is allowed
        header.validationStatus =
            valid ? ITokenomics.ValidationStatus.APPROVED_1 : ITokenomics.ValidationStatus.REJECTED_2;

        p.proposalHeader = HostLib.packProposalHeader(header);

        if (valid) {
            /// @dev Ensure that provided payload is equal to the original one
            require(p.payloadHash == HostUpdateLib.getPayloadHash(payload), IHost.IncorrectProposalPayload());
        }

        if (valid && !header.votingRequired) {
            /// @dev Execute instantly approved proposals that do not require voting
            _doAction(p.daoUid, header.action, payload, proposalId);
        }

        emit IHost.ProposalValidated(proposalId, valid);
    }

    //region -------------------------------------- Update instantly or through proposals
    function _doAction(uint daoUid, ITokenomics.DAOAction action, bytes memory payload, bytes32 proposalId) internal {
        if (action == ITokenomics.DAOAction.UPDATE_IMAGES_0) {
            HostUpdateLib.updateImages(daoUid, payload);
        } else if (action == ITokenomics.DAOAction.UPDATE_SOCIALS_1) {
            HostUpdateLib.updateSocials(daoUid, payload);
        } else if (action == ITokenomics.DAOAction.UPDATE_NAMING_2) {
            HostUpdateLib.updateNaming(daoUid, payload);
        } else if (action == ITokenomics.DAOAction.UPDATE_UNITS_3) {
            HostUpdateLib.updateUnitsForProposal(daoUid, payload, proposalId);
        } else if (action == ITokenomics.DAOAction.UPDATE_FUNDING_4) {
            HostUpdateLib.updateFunding(daoUid, payload);
        } else if (action == ITokenomics.DAOAction.UPDATE_VESTING_5) {
            HostUpdateLib.updateVesting(daoUid, payload);
        } else if (action == ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6) {
            HostUpdateLib.updateDaoParameters(daoUid, payload);
        } else if (action == ITokenomics.DAOAction.UPDATE_SALT_7) {
            HostUpdateLib.updateSalt(daoUid, payload);
        } else if (action == ITokenomics.DAOAction.UPDATE_BRIDGED_DAO_9) {
            HostBridgeLib.sendBridgedAction(daoUid, payload, proposalId);
        } else {
            // todo other actions
            revert IHost.NotImplemented();
        }
    }

    function _beforeUpdate(string memory symbol) internal view returns (InitData memory dest) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        dest.daoUid = HostLib.getDaoUid($, symbol);
        dest.phase = $.segment2[dest.daoUid].phase;
        require(dest.daoUid != 0, IHost.IncorrectDao());
        dest.instant = dest.phase == ITokenomics.LifecyclePhase.DRAFT_0;
        if (dest.instant) {
            require($.segment3[dest.daoUid].deployer == msg.sender, IHost.YouAreNotOwnerOf(symbol));
        }
        return dest;
    }

    /// @notice Update instantly / create proposal to update DAO values
    /// @param symbol DAO symbol
    /// @param action Action kind, see ITokenomics.DAOAction
    /// @param payload Data of the action. Its format depend on the action kind.
    /// This data should be passed together with {proposalId} to {receiveVotingResults} after voting
    /// @param metadata Additional data that is not stored on-chain, but emitted in the event and can be used off-chain
    function updateDAO(string calldata symbol, uint16 action, bytes memory payload, bytes memory metadata) external {
        InitData memory init = _beforeUpdate(symbol);

        /// @dev Currently metadata is required by units-update only
        require(
            metadata.length == 0 || action == uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
            IHost.InvalidMetadataForAction()
        );

        if (action == uint16(ITokenomics.DAOAction.UPDATE_IMAGES_0)) {
            _updateImages(init, payload);
        } else if (action == uint16(ITokenomics.DAOAction.UPDATE_SOCIALS_1)) {
            _updateSocials(init, payload);
        } else if (action == uint16(ITokenomics.DAOAction.UPDATE_NAMING_2)) {
            _updateNaming(init, payload);
        } else if (action == uint16(ITokenomics.DAOAction.UPDATE_UNITS_3)) {
            _updateUnits(init, payload, metadata);
        } else if (action == uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4)) {
            _updateFunding(init, payload);
        } else if (action == uint16(ITokenomics.DAOAction.UPDATE_VESTING_5)) {
            _updateVesting(init, payload);
        } else if (action == uint16(ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6)) {
            _updateDaoParameters(init, payload);
        } else if (action == uint16(ITokenomics.DAOAction.UPDATE_SALT_7)) {
            _updateSalts(init, payload);
        } else if (action == uint16(ITokenomics.DAOAction.UPDATE_DAO_CHAIN_SETTINGS_8)) {
            _updateDaoChainSettings(init, payload);
        } else {
            revert IHost.NotImplemented();
        }
    }

    /// @dev Update/create proposal to update implementations of the DAO contracts
    function _updateImages(InitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        ITokenomics.DaoImages memory images = HostEncodingLib.decodeDaoImages(payload);

        if (d_.instant) {
            HostUpdateLib.updateImages(d_.daoUid, images);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_IMAGES_0, d_.instant, false);
            HostUpdateLib.proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update DAO naming (name and symbol)
    function _updateNaming(InitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        ITokenomics.DaoNames memory daoNames = HostEncodingLib.decodeDaoNames(payload);

        HostUpdateLib.ActionParams memory p =
            HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_NAMING_2, false, true);

        HostUpdateLib._validateNaming(daoNames.name, daoNames.symbol, HostConfigLib.getHostGlobalSettings());
        HostUpdateLib.proposeAction(d_.daoUid, payload, p);
    }

    /// @notice Update/create proposal to update list of socials of the DAO
    /// Instant update forbidden. Validation of the provided links is required before updating socials.
    function _updateSocials(InitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        HostEncodingLib.decodeSocials(payload);

        HostUpdateLib.ActionParams memory p =
            HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_SOCIALS_1, d_.instant, true);
        HostUpdateLib.proposeAction(d_.daoUid, payload, p);
    }

    /// @notice Update/create proposal to update tokenomics units of the DAO
    function _updateUnits(InitData memory d_, bytes memory payload, bytes memory metadata_) internal {
        /// @dev Ensure that provided payload is in correct format
        IDAOData.UnitDataInput[] memory units = HostEncodingLib.decodeUnits(payload);
        IDAOData.UnitMetaData[] memory unitsMetadata = HostEncodingLib.decodeUnitsMetadata(metadata_);

        require(HostConfigLib.getHostGlobalSettings().priceUnit == 0, IHost.NotImplemented());

        bytes32 proposalId;

        // todo on initial chain: update list of chains on which the unit is bridged, see UnitData.chainIds

        if (d_.instant) {
            HostUpdateLib.updateUnits(d_.daoUid, units, 0, unitsMetadata); // 0 - instant update
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_UNITS_3, d_.instant, false);
            proposalId = HostUpdateLib.proposeAction(d_.daoUid, payload, p);

            emit IHost.ProposalToUpdateDaoUnits(proposalId, d_.daoUid, units, unitsMetadata);
        }
    }

    /// @notice Update/create proposal to update funding rounds of the DAO
    function _updateFunding(InitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        ITokenomics.Funding memory funding = HostEncodingLib.decodeFunding(payload);

        HostUpdateLib._validateFunding(d_.phase, funding, HostConfigLib.getHostGlobalSettings());

        if (d_.instant) {
            HostUpdateLib.updateFunding(d_.daoUid, funding);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_FUNDING_4, d_.instant, false);
            HostUpdateLib.proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update vesting schedules of the DAO
    function _updateVesting(InitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        ITokenomics.Vesting[] memory vesting = HostEncodingLib.decodeVesting(payload);

        HostUpdateLib._validateVestingList(d_.phase, vesting, HostConfigLib.getHostGlobalSettings());

        if (d_.instant) {
            HostUpdateLib.updateVesting(d_.daoUid, vesting);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_VESTING_5, d_.instant, false);
            HostUpdateLib.proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update global DAO parameters on current chain
    function _updateDaoParameters(InitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        ITokenomics.DaoParameters memory daoParameters_ = HostEncodingLib.decodeDaoParameters(payload);

        HostUpdateLib._validateDaoParameters(daoParameters_, HostConfigLib.getHostGlobalSettings());

        if (d_.instant) {
            HostUpdateLib.updateDaoParameters(d_.daoUid, daoParameters_);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6, d_.instant, false);
            HostUpdateLib.proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update salts
    function _updateSalts(InitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        (uint16[] memory contractIndices, bytes32[] memory salt_) = HostEncodingLib.decodeSalt(payload);

        HostUpdateLib._validateSalt(d_.daoUid, contractIndices, salt_);

        if (d_.instant) {
            HostUpdateLib.updateSalt(d_.daoUid, contractIndices, salt_);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_SALT_7, d_.instant, false);
            HostUpdateLib.proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update chain-related DAO parameters on current chain
    function _updateDaoChainSettings(InitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        ITokenomics.DaoChainSettings memory settings = HostEncodingLib.decodeDaoChainSettings(payload);

        // todo validate settings?

        if (d_.instant) {
            HostUpdateLib.updateDaoChainSettings(d_.daoUid, settings);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_DAO_CHAIN_SETTINGS_8, d_.instant, false);
            HostUpdateLib.proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Create proposal to update bridged DAO version of the DAO on other chain(s)
    function updateBridgedDao(
        string calldata symbol,
        uint16 actionKind,
        uint32[] calldata dstEids,
        bytes[] calldata actionPayloads
    ) external {
        InitData memory _d = _beforeUpdate(symbol);

        HostBridgeLib.verify(_d.daoUid, actionKind, dstEids, actionPayloads);

        HostUpdateLib.ActionParams memory p =
            HostUpdateLib.getBridgedActionParams(ITokenomics.DAOAction.UPDATE_BRIDGED_DAO_9, actionKind);
        bytes memory payload = HostEncodingLib.encodeBridgedAction(
            actionKind, dstEids, actionPayloads, HostEncodingLib.PAYLOAD_API_VERSION
        );
        HostUpdateLib.proposeAction(_d.daoUid, payload, p);
    }

    //endregion -------------------------------------- Update instantly or through proposals
}
