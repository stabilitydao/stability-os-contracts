// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EfficientHashLib} from "@solady/utils/EfficientHashLib.sol";
import {HostBridgeLib} from "./HostBridgeLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {HostEncodingLib} from "./HostEncodingLib.sol";
import {HostLib} from "./HostLib.sol";
import {HostUpdateLib} from "./HostUpdateLib.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {ISeedToken} from "../interfaces/ISeedToken.sol";

/// @notice Library with proposal related functions
library HostProposalLib {
    //region -------------------------------------- Data types
    /// @dev Initial data that is read before updating a DAO
    struct LocalInitData {
        uint daoUid;
        /// @dev True if instant update is possible
        bool instant;
        /// @dev Current phase of the DAO
        IDAOData.LifecyclePhase phase;
    }

    struct ActionParams {
        /// @param action Action type of the proposal
        IDAOData.DAOAction action;
        /// @param validationRequired True if proposal requires validation by admins before voting
        bool validationRequired;
        /// @param votingRequired True if proposal requires voting by DAO members
        bool votingRequired;
    }

    //endregion -------------------------------------- Data types

    //region -------------------------------------- Main logic
    /// @notice Receive voting results from voting module and execute proposal if approved
    /// @param proposalId Proposal unique id
    /// @param succeed True if proposal is approved
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if proposal was rejected.
    function receiveVotingResults(bytes32 proposalId, bool succeed, bytes memory payload) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.ProposalData storage p = $.proposals[proposalId];
        HostLib.ProposalHeader memory header = HostLib.unpackProposalHeader(p.proposalHeader);

        uint daoUid = p.daoUid;

        require(daoUid != 0, IHost.IncorrectProposal());
        require(header.status == IDAOData.VotingStatus.VOTING_0, IHost.AlreadyReceived());

        /// @dev Only proposals that require a voting can receive voting results
        require(header.votingRequired, IHost.VotingNotRequired());

        /// @dev Only validated proposals or proposal that do not require validation can receive voting results
        require(
            !header.validationRequired || header.validationStatus == IDAOData.ValidationStatus.APPROVED_1,
            IHost.ProposalNotValidated()
        );

        header.status = succeed ? IDAOData.VotingStatus.APPROVED_1 : IDAOData.VotingStatus.REJECTED_2;
        p.proposalHeader = HostLib.packProposalHeader(header);

        if (succeed) {
            /// @dev Ensure that provided payload is equal to the original one
            require(p.payloadHash == getPayloadHash(payload), IHost.IncorrectProposalPayload());

            _doAction(daoUid, header.action, payload, p.id);
        }
    }

    /// @notice Quote gas cost to perform action suggested by proposal
    /// The action can be performed by calling either {receiveVotingResults(succeeded=true)} or {validateProposal(valid=true)}
    /// @param proposalId Proposal unique id
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if proposal was rejected.
    /// @param method Kind of operation that you are going to perform: 0 - receiveVotingResults, 1 - validateProposal
    /// @return fee Estimated fee (in native token) to process the voting results
    function quoteProposalAction(
        bytes32 proposalId,
        bytes memory payload,
        IHost.ValidationMethod method
    ) external view returns (uint fee) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.ProposalData storage p = $.proposals[proposalId];

        HostLib.ProposalHeader memory header = HostLib.unpackProposalHeader(p.proposalHeader);
        IDAOData.DAOAction action = header.action;
        if (_isActionRunnable(header, method)) {
            if (action == IDAOData.DAOAction.UPDATE_BRIDGED_DAO_9) {
                (uint16 actionKind, uint32[] memory dstEids, bytes[] memory actionPayloads) =
                    HostEncodingLib.decodeBridgedAction(payload);
                fee = HostBridgeLib.quoteSendBridgedAction(p.daoUid, actionKind, dstEids, actionPayloads);
            } else {
                // todo not-bridged actions with cross-chain messages: updateNaming
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
        HostLib.ProposalData storage p = $.proposals[proposalId];
        HostLib.ProposalHeader memory header = HostLib.unpackProposalHeader(p.proposalHeader);

        require(p.daoUid != 0, IHost.IncorrectProposal());

        /// @dev Only proposals that require a validation can be validated.
        require(header.validationRequired, IHost.ValidationNotRequired());

        /// @dev Any proposal can be validated only once. Re-validation is not allowed to simplify uses cases
        require(header.validationStatus == IDAOData.ValidationStatus.NONE_0, IHost.AlreadyValidated());

        /// @dev Save validation status to prevent re-validation
        header.validationStatus = valid ? IDAOData.ValidationStatus.APPROVED_1 : IDAOData.ValidationStatus.REJECTED_2;
        p.proposalHeader = HostLib.packProposalHeader(header);

        if (valid) {
            /// @dev Ensure that provided payload is equal to the original one
            require(p.payloadHash == getPayloadHash(payload), IHost.IncorrectProposalPayload());
        }

        if (valid && !header.votingRequired) {
            /// @dev Execute instantly approved proposals that do not require voting
            _doAction(p.daoUid, header.action, payload, proposalId);
        }

        emit IHost.ProposalValidated(proposalId, valid);
    }

    /// @notice Update instantly / create proposal to update DAO values
    /// @param symbol DAO symbol
    /// @param action Action kind, see IDAOData.DAOAction
    /// @param payload Data of the action. Its format depend on the action kind.
    /// This data should be passed together with {proposalId} to {receiveVotingResults} after voting
    /// @param emitData Additional data that is not stored on-chain, but emitted in the event and can be used off-chain
    function updateDAO(string calldata symbol, uint16 action, bytes memory payload, bytes memory emitData) external {
        LocalInitData memory init = _beforeUpdate(symbol);

        /// @dev Currently metadata is required by units-update only
        require(
            emitData.length == 0 || action == uint16(IDAOData.DAOAction.UPDATE_UNITS_3),
            IHost.InvalidEmitDataForAction()
        );

        if (action == uint16(IDAOData.DAOAction.UPDATE_IMAGES_0)) {
            _updateImages(init, payload);
        } else if (action == uint16(IDAOData.DAOAction.UPDATE_SOCIALS_1)) {
            _updateSocials(init, payload);
        } else if (action == uint16(IDAOData.DAOAction.UPDATE_NAMING_2)) {
            _updateNaming(init, payload);
        } else if (action == uint16(IDAOData.DAOAction.UPDATE_UNITS_3)) {
            _updateUnits(init, payload, emitData);
        } else if (action == uint16(IDAOData.DAOAction.UPDATE_FUNDING_4)) {
            _updateFunding(init, payload);
        } else if (action == uint16(IDAOData.DAOAction.UPDATE_VESTING_5)) {
            _updateVesting(init, payload);
        } else if (action == uint16(IDAOData.DAOAction.UPDATE_DAO_PARAMETERS_6)) {
            _updateDaoParameters(init, payload);
        } else if (action == uint16(IDAOData.DAOAction.UPDATE_SALT_7)) {
            _updateSalts(init, payload);
        } else if (action == uint16(IDAOData.DAOAction.UPDATE_DAO_CHAIN_SETTINGS_8)) {
            _updateDaoChainSettings(init, payload);
        } else if (action == uint16(IDAOData.DAOAction.UPDATE_GOVERNANCE_SETTINGS_10)) {
            _updateGovernanceSettings(init, payload);
        } else {
            revert IHost.NotImplemented();
        }
    }

    /// @notice Create proposal to update bridged DAO version of the DAO on other chain(s)
    /// @param symbol DAO symbol
    /// @param bridgedAction_ Kind of the action to be executed on other chain(s), see IHost.BridgedActions
    /// @param dstEids Array of destination LayerZero-endpoints where the action will be executed
    /// @param actionPayloads Array of payloads for the action to be executed on chains with provided endpoints
    function updateBridgedDao(
        string calldata symbol,
        uint16 bridgedAction_,
        uint32[] calldata dstEids,
        bytes[] calldata actionPayloads
    ) external {
        LocalInitData memory _d = _beforeUpdate(symbol);

        HostBridgeLib.verify(_d.daoUid, bridgedAction_, dstEids, actionPayloads);

        bytes memory payload =
            HostEncodingLib.encodeBridgedAction(bridgedAction_, dstEids, actionPayloads, HostEncodingLib.API_VERSION);
        ActionParams memory p = _getBridgedActionParams(IDAOData.DAOAction.UPDATE_BRIDGED_DAO_9, bridgedAction_);
        _proposeAction(_d.daoUid, payload, p);
    }

    //endregion -------------------------------------- Main logic

    //region -------------------------------------- Internal logic for updating instantly or through proposals
    /// @dev Execute action according validated and approved proposal to update DAO values
    function _doAction(uint daoUid, IDAOData.DAOAction action, bytes memory payload, bytes32 proposalId) internal {
        if (action == IDAOData.DAOAction.UPDATE_IMAGES_0) {
            HostUpdateLib.updateImages(daoUid, payload);
        } else if (action == IDAOData.DAOAction.UPDATE_SOCIALS_1) {
            HostUpdateLib.updateSocials(daoUid, payload);
        } else if (action == IDAOData.DAOAction.UPDATE_NAMING_2) {
            HostUpdateLib.updateNaming(daoUid, payload);
        } else if (action == IDAOData.DAOAction.UPDATE_UNITS_3) {
            HostUpdateLib.updateUnitsForProposal(daoUid, payload, proposalId);
        } else if (action == IDAOData.DAOAction.UPDATE_FUNDING_4) {
            HostUpdateLib.updateFunding(daoUid, payload);
        } else if (action == IDAOData.DAOAction.UPDATE_VESTING_5) {
            HostUpdateLib.updateVesting(daoUid, payload);
        } else if (action == IDAOData.DAOAction.UPDATE_DAO_PARAMETERS_6) {
            HostUpdateLib.updateDaoParameters(daoUid, payload);
        } else if (action == IDAOData.DAOAction.UPDATE_SALT_7) {
            HostUpdateLib.updateSalt(daoUid, payload);
        } else if (action == IDAOData.DAOAction.UPDATE_DAO_CHAIN_SETTINGS_8) {
            HostUpdateLib.updateDaoChainSettings(daoUid, payload);
        } else if (action == IDAOData.DAOAction.UPDATE_BRIDGED_DAO_9) {
            HostBridgeLib.sendBridgedAction(daoUid, payload, proposalId);
        } else if (action == IDAOData.DAOAction.UPDATE_GOVERNANCE_SETTINGS_10) {
            HostUpdateLib.updateGovernanceSettings(daoUid, payload);
        } else {
            revert IHost.NotImplemented();
        }
    }

    function _beforeUpdate(string memory symbol) internal view returns (LocalInitData memory dest) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        dest.daoUid = HostLib.getDaoUid($, symbol);
        dest.phase = $.segment2[dest.daoUid].phase;
        require(dest.daoUid != 0, IHost.IncorrectDao());
        dest.instant = dest.phase == IDAOData.LifecyclePhase.DRAFT_0; // todo Inception?
        if (dest.instant) {
            require($.segment3[dest.daoUid].deployer == msg.sender, IHost.YouAreNotOwnerOf(symbol));
        }
        return dest;
    }

    /// @dev Update/create proposal to update implementations of the DAO contracts
    function _updateImages(LocalInitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        IDAOData.DaoImages memory images = HostEncodingLib.decodeDaoImages(payload);

        if (d_.instant) {
            HostUpdateLib.updateImages(d_.daoUid, images);
        } else {
            ActionParams memory p = _getActionParams(IDAOData.DAOAction.UPDATE_IMAGES_0, d_.instant, false);
            _proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update DAO naming (name and symbol)
    function _updateNaming(LocalInitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        IDAOData.DaoNames memory daoNames = HostEncodingLib.decodeDaoNames(payload);

        ActionParams memory p = _getActionParams(IDAOData.DAOAction.UPDATE_NAMING_2, d_.instant, true);

        HostUpdateLib.validateNaming(daoNames.name, daoNames.symbol, HostConfigLib.getHostGlobalSettings());
        _proposeAction(d_.daoUid, payload, p);
    }

    /// @notice Update/create proposal to update list of socials of the DAO
    /// Instant update forbidden. Validation of the provided links is required before updating socials.
    function _updateSocials(LocalInitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        HostEncodingLib.decodeSocials(payload);

        ActionParams memory p = _getActionParams(IDAOData.DAOAction.UPDATE_SOCIALS_1, d_.instant, true);
        _proposeAction(d_.daoUid, payload, p);
    }

    /// @notice Update/create proposal to update tokenomics units of the DAO
    function _updateUnits(LocalInitData memory d_, bytes memory payload, bytes memory emitData_) internal {
        /// @dev Ensure that provided payload is in correct format
        IDAOData.UnitDataInput[] memory units = HostEncodingLib.decodeUnits(payload);
        IDAOData.UnitEmitData[] memory emitData = HostEncodingLib.decodeUnitsEmitData(emitData_);

        bytes32 proposalId;

        // todo on initial chain: update list of chains on which the unit is bridged, see UnitData.chainIds

        if (d_.instant) {
            HostUpdateLib.updateUnits(d_.daoUid, units, 0, emitData); // 0 - instant update
        } else {
            ActionParams memory p = _getActionParams(IDAOData.DAOAction.UPDATE_UNITS_3, d_.instant, false);
            proposalId = _proposeAction(d_.daoUid, payload, p);

            emit IHost.ProposalToUpdateDaoUnits(proposalId, d_.daoUid, units, emitData);
        }
    }

    /// @notice Update/create proposal to update funding rounds of the DAO
    function _updateFunding(LocalInitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        IDAOData.Funding memory funding = HostEncodingLib.decodeFunding(payload);

        HostUpdateLib.validateFunding(d_.phase, funding, HostConfigLib.getHostGlobalSettings());

        if (d_.instant) {
            HostUpdateLib.updateFunding(d_.daoUid, funding);
        } else {
            ActionParams memory p = _getActionParams(IDAOData.DAOAction.UPDATE_FUNDING_4, d_.instant, false);
            _proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update vesting schedules of the DAO
    function _updateVesting(LocalInitData memory d_, bytes memory payload) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        /// @dev Ensure that provided payload is in correct format
        IDAOData.Vesting[] memory vesting = HostEncodingLib.decodeVesting(payload);

        uint tgeClaim = $.funding[HostLib.getKey(d_.daoUid, uint(IDAOData.FundingType.TGE_1))].claim;
        HostUpdateLib.validateVestingList(d_.phase, vesting, HostConfigLib.getHostGlobalSettings(), tgeClaim);

        if (d_.instant) {
            HostUpdateLib.updateVesting(d_.daoUid, vesting);
        } else {
            ActionParams memory p = _getActionParams(IDAOData.DAOAction.UPDATE_VESTING_5, d_.instant, false);
            _proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update global DAO parameters on current chain
    function _updateDaoParameters(LocalInitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        IDAOData.DaoParameters memory _daoParameters = HostEncodingLib.decodeDaoParameters(payload);

        HostUpdateLib.validateDaoParameters(d_.daoUid, d_.phase, _daoParameters, HostConfigLib.getHostGlobalSettings());

        if (d_.instant) {
            HostUpdateLib.updateDaoParameters(d_.daoUid, _daoParameters);
        } else {
            ActionParams memory p = _getActionParams(IDAOData.DAOAction.UPDATE_DAO_PARAMETERS_6, d_.instant, false);
            _proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update salts
    function _updateSalts(LocalInitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        (uint16[] memory contractIndices, bytes32[] memory salt_) = HostEncodingLib.decodeSalt(payload);

        HostUpdateLib.validateSalt(d_.daoUid, contractIndices, salt_);

        if (d_.instant) {
            HostUpdateLib.updateSalt(d_.daoUid, contractIndices, salt_);
        } else {
            ActionParams memory p = _getActionParams(IDAOData.DAOAction.UPDATE_SALT_7, d_.instant, false);
            _proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update chain-related DAO parameters on current chain
    function _updateDaoChainSettings(LocalInitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        IDAOData.DaoChainSettings memory settings = HostEncodingLib.decodeDaoChainSettings(payload);

        HostUpdateLib.validateDaoChainSettings(settings);

        if (d_.instant) {
            HostUpdateLib.updateDaoChainSettings(d_.daoUid, settings);
        } else {
            ActionParams memory p = _getActionParams(IDAOData.DAOAction.UPDATE_DAO_CHAIN_SETTINGS_8, d_.instant, false);
            _proposeAction(d_.daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update governance settings on current chain
    function _updateGovernanceSettings(LocalInitData memory d_, bytes memory payload) internal {
        /// @dev Ensure that provided payload is in correct format
        IDAOData.GovernanceSettings memory settings = HostEncodingLib.decodeGovernanceSettings(payload);

        if (d_.instant) {
            HostUpdateLib.updateGovernanceSettings(d_.daoUid, settings);
        } else {
            ActionParams memory p =
                _getActionParams(IDAOData.DAOAction.UPDATE_GOVERNANCE_SETTINGS_10, d_.instant, false);
            _proposeAction(d_.daoUid, payload, p);
        }
    }

    //endregion -------------------------------------- Internal logic for updating instantly or through proposals

    //region -------------------------------------- Proposal utils

    /// @notice Check if action can be executed according to the proposal header and kind of the operation that you are going to perform
    function _isActionRunnable(
        HostLib.ProposalHeader memory header,
        IHost.ValidationMethod method
    ) internal pure returns (bool) {
        if (method == IHost.ValidationMethod.VOTING_0) {
            /// @dev receiveVotingResults can be called only for approved proposals that require voting
            return header.votingRequired && header.status == IDAOData.VotingStatus.VOTING_0
                && (!header.validationRequired || header.validationStatus == IDAOData.ValidationStatus.APPROVED_1);
        } else {
            /// @dev validateProposal can be called only for proposals that require validation and are not validated yet
            return (header.validationRequired && header.validationStatus == IDAOData.ValidationStatus.NONE_0)
                && (!header.votingRequired || header.status == IDAOData.VotingStatus.APPROVED_1);
        }
    }

    /// @dev Trivial function to generate ActionParams struct.
    /// All logic of values detection should be implemented on the caller side.
    function _getActionParams(
        IDAOData.DAOAction action_,
        bool instantExecution,
        bool validationRequired
    ) internal pure returns (ActionParams memory) {
        return ActionParams({
            action: action_, validationRequired: validationRequired, votingRequired: !instantExecution
        });
    }

    /// @dev Generate ActionParams for bridged actions.
    /// Logic of values detection is here.
    function _getBridgedActionParams(
        IDAOData.DAOAction action_,
        uint16 bridgedActionKind_
    ) internal pure returns (ActionParams memory dest) {
        dest = ActionParams({
            action: action_,
            validationRequired: 
            /// @dev Admin should ensure that provided salts are not used in any other proposals on target chain
            bridgedActionKind_ == uint16(IHost.BridgedActions.SET_SALTS_5)
                /// @dev Admin should ensure that provided salts are not used in any other proposals on target chain
                || bridgedActionKind_ == uint16(IHost.BridgedActions.BRIDGE_DAO_1),
            votingRequired: true
        });
    }

    /// @notice Create new proposal
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded proposal data. Assume below that the payload is already validated.
    /// @param params_ Parameters of the proposal action
    /// @return proposalId Id of the created proposal. It is unique across all DAOs
    function _proposeAction(uint daoUid, bytes memory payload, ActionParams memory params_) internal returns (bytes32) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        // @dev Proposal can be created on initial chain only
        require($.segment3[daoUid].initialChain == block.chainid, IHost.NotInitialChain());

        _checkUserPower(daoUid);

        /// @dev Hash of the payload
        bytes32 payloadHash = getPayloadHash(payload);

        /// @dev Unique proposal id
        bytes32 proposalId = _createProposalId(daoUid, params_.action, payloadHash);

        HostLib.ProposalData storage proposal = $.proposals[proposalId];
        proposal.daoUid = daoUid;

        HostLib.ProposalHeader memory proposalHeader = HostLib.ProposalHeader({
            action: params_.action,
            validationRequired: params_.validationRequired,
            votingRequired: params_.votingRequired,
            validationStatus: IDAOData.ValidationStatus.NONE_0,
            status: IDAOData.VotingStatus.VOTING_0,
            created: uint64(block.timestamp)
        });
        proposal.proposalHeader = HostLib.packProposalHeader(proposalHeader);

        proposal.id = proposalId;
        proposal.payloadHash = EfficientHashLib.hash(payload);

        $.daoProposals[daoUid].push(proposalId);

        /// @dev Emit payload, don't store it on chain
        emit IHost.Proposal(daoUid, params_.action, proposalId, payloadHash, payload);

        return proposalId;
    }

    /// @dev Ensure that msg.sender has enough user power to make a proposal
    function _checkUserPower(uint daoUid) internal view {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.LifecyclePhase phase = $.segment2[daoUid].phase;
        if (phase == IDAOData.LifecyclePhase.DRAFT_0 || phase == IDAOData.LifecyclePhase.INCEPTION_1) {
            // Proposal created at DRAFT phase doesn't require any power
            // it doesn't require voting, only validation
        } else if (
            phase == IDAOData.LifecyclePhase.SEED_2 || phase == IDAOData.LifecyclePhase.SEED_FAILED_3
                || phase == IDAOData.LifecyclePhase.DEVELOPMENT_4 || phase == IDAOData.LifecyclePhase.TGE_5
        ) {
            ISeedToken seedToken = ISeedToken($.deployments[daoUid].seedToken);
            uint power = seedToken.balanceOf(msg.sender);
            uint totalPower = seedToken.totalSupply();
            require(
                totalPower != 0
                    && $.daoParameters[daoUid].proposalThreshold <= power * HostLib.DENOMINATOR / totalPower,
                IHost.NotEnoughUserPower()
            );
        } else {
            // todo Add implementation of checking dao token power in LIVE and later phases
            revert IHost.NotImplemented();
        }
    }

    /// @notice Create unique proposal id
    /// @param daoUid Unique id of the DAO
    /// @param action Action type of the proposal
    /// @param payloadHash Hash of the proposal payload
    /// @return proposalId Id of the created proposal. It is unique across all DAOs
    function _createProposalId(
        uint daoUid,
        IDAOData.DAOAction action,
        bytes32 payloadHash
    ) internal view returns (bytes32) {
        return EfficientHashLib.hash(
            abi.encode(daoUid, HostLib.getHostStorage().daoProposals[daoUid].length, action, payloadHash)
        );
    }

    /// @notice Calculate hash of the proposal payload
    /// @param payload Encoded proposal data
    /// @return Hash of the payload
    function getPayloadHash(bytes memory payload) internal pure returns (bytes32) {
        return EfficientHashLib.hash(payload);
    }

    //endregion -------------------------------------- Proposal utils
}
