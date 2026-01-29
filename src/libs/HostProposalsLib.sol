// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostUpdateBridgedLib} from "./HostUpdateBridgedLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {HostEncodingLib} from "./HostEncodingLib.sol";
import {HostLib} from "./HostLib.sol";
import {HostUpdateLib} from "./HostUpdateLib.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {IHost} from "../interfaces/IHost.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";

/// @notice Library with proposal related functions
library HostProposalsLib {
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
            if (action == ITokenomics.DAOAction.UPDATE_BRIDGED_DAO_8) {
                (uint16 actionKind, uint32[] memory dstEids, bytes[] memory actionPayloads) =
                    HostEncodingLib.decodeBridgedAction(payload);
                fee = HostUpdateBridgedLib.quoteSendBridgedAction(p.daoUid, actionKind, dstEids, actionPayloads);
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
        } else if (action == ITokenomics.DAOAction.UPDATE_BRIDGED_DAO_8) {
            HostUpdateBridgedLib.sendBridgedAction(daoUid, payload, proposalId);
        } else {
            // todo other actions
            revert IHost.NotImplemented();
        }
    }

    function _beforeUpdate(string memory daoSymbol)
        internal
        view
        returns (HostLib.HostStorage storage $, uint daoUid, bool instant, ITokenomics.LifecyclePhase phase)
    {
        $ = HostLib.getHostStorage();
        daoUid = HostLib.getDaoUid($, daoSymbol);
        phase = $.segment2[daoUid].phase;
        require(daoUid != 0, IHost.IncorrectDao());
        instant = phase == ITokenomics.LifecyclePhase.DRAFT_0;
        if (instant) {
            require($.segment3[daoUid].deployer == msg.sender, IHost.YouAreNotOwnerOf(daoSymbol));
        }
    }

    /// @notice Update/create proposal to update implementations of the DAO contracts
    function updateImages(string memory daoSymbol, ITokenomics.DaoImages memory images) external {
        (, uint daoUid, bool instant,) = _beforeUpdate(daoSymbol);

        if (instant) {
            HostUpdateLib.updateImages(daoUid, images);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_IMAGES_0, instant, false);
            bytes memory payload = HostEncodingLib.encodeDaoImages(images, HostEncodingLib.PAYLOAD_API_VERSION);
            HostUpdateLib.proposeAction(daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update list of socials of the DAO
    /// Instant update forbidden. Validation of the provided links is required before updating socials.
    function updateSocials(string memory daoSymbol, string[] memory socials) external {
        (, uint daoUid, bool instant,) = _beforeUpdate(daoSymbol);

        HostUpdateLib.ActionParams memory p =
            HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_SOCIALS_1, instant, true);
        bytes memory payload = HostEncodingLib.encodeSocials(socials);
        HostUpdateLib.proposeAction(daoUid, payload, p);
    }

    /// @notice Update/create proposal to update tokenomics units of the DAO
    function updateUnits(
        string memory daoSymbol,
        IDAOData.UnitDataInput[] memory units,
        IDAOData.UnitMetaData[] memory metadata
    ) external {
        (, uint daoUid, bool instant,) = _beforeUpdate(daoSymbol);

        require(HostConfigLib.getHostGlobalSettings().priceUnit == 0, IHost.NotImplemented());

        bytes32 proposalId;

        if (instant) {
            HostUpdateLib.updateUnits(daoUid, units, 0, metadata); // 0 - instant update
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_UNITS_3, instant, false);
            bytes memory payload = HostEncodingLib.encodeUnits(units, HostEncodingLib.PAYLOAD_API_VERSION);
            proposalId = HostUpdateLib.proposeAction(daoUid, payload, p);

            emit IHost.ProposalToUpdateDaoUnits(proposalId, daoUid, units, metadata);
        }
    }

    /// @notice Update/create proposal to update funding rounds of the DAO
    function updateFunding(string memory daoSymbol, ITokenomics.Funding memory funding) external {
        (, uint daoUid, bool instant, ITokenomics.LifecyclePhase phase) = _beforeUpdate(daoSymbol);

        HostUpdateLib._validateFunding(phase, funding, HostConfigLib.getHostGlobalSettings());

        if (instant) {
            HostUpdateLib.updateFunding(daoUid, funding);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_FUNDING_4, instant, false);
            bytes memory payload = HostEncodingLib.encodeFunding(funding, HostEncodingLib.PAYLOAD_API_VERSION);
            HostUpdateLib.proposeAction(daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update vesting schedules of the DAO
    function updateVesting(string memory daoSymbol, ITokenomics.Vesting[] memory vesting) external {
        (, uint daoUid, bool instant, ITokenomics.LifecyclePhase phase) = _beforeUpdate(daoSymbol);

        HostUpdateLib._validateVestingList(phase, vesting, HostConfigLib.getHostGlobalSettings());

        if (instant) {
            HostUpdateLib.updateVesting(daoUid, vesting);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_VESTING_5, instant, false);
            bytes memory payload = HostEncodingLib.encodeVesting(vesting, HostEncodingLib.PAYLOAD_API_VERSION);
            HostUpdateLib.proposeAction(daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update DAO naming (name and symbol)
    function updateNaming(string memory daoSymbol, ITokenomics.DaoNames memory daoNames_) external {
        (, uint daoUid, bool instant,) = _beforeUpdate(daoSymbol);

        // todo validation is required

        HostUpdateLib._validateNaming(daoNames_.name, daoNames_.symbol, HostConfigLib.getHostGlobalSettings());

        if (instant) {
            HostUpdateLib.updateNaming(daoUid, daoNames_);
        } else {
            // todo
            // Renaming through proposals is not implemented yet
            // because somebody should pay for cross-chain messages
            // it's necessary to implement quoteReceiveVotingResults
            revert IHost.NotImplemented();

            //            bytes memory payload = HostEncodingLib.encodeDaoNames(daoNames_, HostEncodingLib.DAO_NAMES_STRUCT_VERSION);
            //            HostUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_NAMING_2, payload, instant, false);
        }
    }

    /// @notice Update/create proposal to update on-chain DAO parameters
    function updateDaoParameters(string memory daoSymbol, ITokenomics.DaoParameters memory daoParameters_) external {
        (, uint daoUid, bool instant,) = _beforeUpdate(daoSymbol);

        HostUpdateLib._validateDaoParameters(daoParameters_, HostConfigLib.getHostGlobalSettings());

        if (instant) {
            HostUpdateLib.updateDaoParameters(daoUid, daoParameters_);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6, instant, false);
            bytes memory payload =
                HostEncodingLib.encodeDaoParameters(daoParameters_, HostEncodingLib.PAYLOAD_API_VERSION);
            HostUpdateLib.proposeAction(daoUid, payload, p);
        }
    }

    /// @notice Update/create proposal to update salts
    function updateSalts(string memory daoSymbol, uint16[] memory contractIndices, bytes32[] memory salt_) external {
        (, uint daoUid, bool instant,) = _beforeUpdate(daoSymbol);

        HostUpdateLib._validateSalt(daoUid, contractIndices, salt_);

        if (instant) {
            HostUpdateLib.updateSalt(daoUid, contractIndices, salt_);
        } else {
            HostUpdateLib.ActionParams memory p =
                HostUpdateLib.getActionParams(ITokenomics.DAOAction.UPDATE_SALT_7, instant, false);
            bytes memory payload =
                HostEncodingLib.encodeSalt(contractIndices, salt_, HostEncodingLib.PAYLOAD_API_VERSION);
            HostUpdateLib.proposeAction(daoUid, payload, p);
        }
    }

    /// @notice Create proposal to update bridged DAO version of the DAO on other chain(s)
    function updateBridgedDao(
        string calldata daoSymbol,
        uint16 actionKind,
        uint32[] calldata dstEids,
        bytes[] calldata actionPayloads
    ) external {
        (, uint daoUid,,) = _beforeUpdate(daoSymbol);

        HostUpdateBridgedLib.verify(daoUid, actionKind, dstEids, actionPayloads);

        HostUpdateLib.ActionParams memory p =
            HostUpdateLib.getBridgedActionParams(ITokenomics.DAOAction.UPDATE_BRIDGED_DAO_8, actionKind);
        bytes memory payload = HostEncodingLib.encodeBridgedAction(
            actionKind, dstEids, actionPayloads, HostEncodingLib.PAYLOAD_API_VERSION
        );
        HostUpdateLib.proposeAction(daoUid, payload, p);
    }

    //endregion -------------------------------------- Update instantly or through proposals
}
