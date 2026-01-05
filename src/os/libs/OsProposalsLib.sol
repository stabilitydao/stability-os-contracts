// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOS} from "../../interfaces/IOS.sol";
import {ITokenomics} from "../../interfaces/ITokenomics.sol";
import {OsLib} from "./OsLib.sol";
import {OsEncodingLib} from "./OsEncodingLib.sol";
import {OsUpdateLib} from "./OsUpdateLib.sol";

/// @notice Library with proposal related functions
library OsProposalsLib {
    /// @notice Receive voting results from voting module and execute proposal if approved
    function receiveVotingResults(bytes32 proposalId, bool succeed) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();

        OsLib.ProposalLocal storage p = $.proposals[proposalId];

        require(p.daoUid != 0, IOS.IncorrectProposal());
        require(p.status == ITokenomics.VotingStatus.VOTING_0, IOS.AlreadyReceived());

        p.status = succeed ? ITokenomics.VotingStatus.APPROVED_1 : ITokenomics.VotingStatus.REJECTED_2;

        ITokenomics.DAOAction action = p.action;
        if (succeed) {
            if (action == ITokenomics.DAOAction.UPDATE_IMAGES_0) {
                OsUpdateLib.updateImages(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_SOCIALS_1) {
                OsUpdateLib.updateSocials(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_UNITS_3) {
                OsUpdateLib.updateUnits(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_FUNDING_4) {
                OsUpdateLib.updateFunding(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_VESTING_5) {
                OsUpdateLib.updateVesting(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_NAMING_2) {
                OsUpdateLib.updateNaming(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6) {
                OsUpdateLib.updateDaoParameters(p.daoUid, p.payload);
            } else {
                // todo other actions
                revert IOS.NonImplemented();
            }
        }
    }

    //region -------------------------------------- Update instantly or through proposals
    function _beforeUpdate(string memory daoSymbol)
        internal
        view
        returns (OsLib.OsStorage storage $, uint daoUid, bool instantExecute, ITokenomics.LifecyclePhase phase)
    {
        $ = OsLib.getOsStorage();
        daoUid = $.daoUids[daoSymbol];
        phase = $.daos[daoUid].phase;
        require(daoUid != 0, IOS.IncorrectDao());
        instantExecute = phase == ITokenomics.LifecyclePhase.DRAFT_0;
        if (instantExecute) {
            require($.daos[daoUid].deployer == msg.sender, IOS.YouAreNotOwnerOf(daoSymbol));
        }
    }

    /// @notice Update/create proposal to update implementations of the DAO contracts
    function updateImages(string memory daoSymbol, ITokenomics.DaoImages memory images) external {
        (, uint daoUid, bool instantExecute,) = _beforeUpdate(daoSymbol);

        if (instantExecute) {
            OsUpdateLib.updateImages(daoUid, images);
        } else {
            bytes memory payload = OsEncodingLib.encodeDaoImages(images, OsEncodingLib.DAO_IMAGES_STRUCT_VERSION);
            OsUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_IMAGES_0, payload);
        }
    }

    /// @notice Update/create proposal to update list of socials of the DAO
    function updateSocials(string memory daoSymbol, string[] memory socials) external {
        (, uint daoUid, bool instantExecute,) = _beforeUpdate(daoSymbol);

        if (instantExecute) {
            OsUpdateLib.updateSocials(daoUid, socials);
        } else {
            bytes memory payload = OsEncodingLib.encodeSocials(socials);
            OsUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_SOCIALS_1, payload);
        }
    }

    /// @notice Update/create proposal to update tokenomics units of the DAO
    function updateUnits(string memory daoSymbol, ITokenomics.UnitInfo[] memory units) external {
        (, uint daoUid, bool instantExecute,) = _beforeUpdate(daoSymbol);

        if (instantExecute) {
            OsUpdateLib.updateUnits(daoUid, units);
        } else {
            bytes memory payload = OsEncodingLib.encodeUnits(units, OsEncodingLib.UNIT_STRUCT_VERSION);
            OsUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_UNITS_3, payload);
        }
    }

    /// @notice Update/create proposal to update funding rounds of the DAO
    function updateFunding(string memory daoSymbol, ITokenomics.Funding memory funding) external {
        (OsLib.OsStorage storage $, uint daoUid, bool instantExecute, ITokenomics.LifecyclePhase phase) =
            _beforeUpdate(daoSymbol);

        OsUpdateLib._validateFunding(phase, funding, $.osSettings[0]);

        if (instantExecute) {
            OsUpdateLib.updateFunding(daoUid, funding);
        } else {
            bytes memory payload = OsEncodingLib.encodeFunding(funding, OsEncodingLib.FUNDING_STRUCT_VERSION);
            OsUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_FUNDING_4, payload);
        }
    }

    /// @notice Update/create proposal to update vesting schedules of the DAO
    function updateVesting(string memory daoSymbol, ITokenomics.Vesting[] memory vesting) external {
        (OsLib.OsStorage storage $, uint daoUid, bool instantExecute, ITokenomics.LifecyclePhase phase) =
            _beforeUpdate(daoSymbol);

        OsUpdateLib._validateVestingList(phase, vesting, $.osSettings[0]);

        if (instantExecute) {
            OsUpdateLib.updateVesting(daoUid, vesting);
        } else {
            bytes memory payload = OsEncodingLib.encodeVesting(vesting, OsEncodingLib.VESTING_STRUCT_VERSION);
            OsUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_VESTING_5, payload);
        }
    }

    /// @notice Update/create proposal to update DAO naming (name and symbol)
    function updateNaming(string memory daoSymbol, ITokenomics.DaoNames memory daoNames_) external {
        (OsLib.OsStorage storage $, uint daoUid, bool instantExecute,) = _beforeUpdate(daoSymbol);

        OsUpdateLib._validateNaming(daoNames_.name, daoNames_.symbol, $.osSettings[0]);

        if (instantExecute) {
            OsUpdateLib.updateNaming(daoUid, daoNames_);
        } else {
            bytes memory payload = OsEncodingLib.encodeDaoNames(daoNames_, OsEncodingLib.DAO_NAMES_STRUCT_VERSION);
            OsUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_NAMING_2, payload);
        }
    }

    /// @notice Update/create proposal to update on-chain DAO parameters
    function updateDaoParameters(string memory daoSymbol, ITokenomics.DaoParameters memory daoParameters_) external {
        (OsLib.OsStorage storage $, uint daoUid, bool instantExecute,) = _beforeUpdate(daoSymbol);

        OsUpdateLib._validateDaoParameters(daoParameters_, $.osSettings[0]);

        if (instantExecute) {
            OsUpdateLib.updateDaoParameters(daoUid, daoParameters_);
        } else {
            bytes memory payload =
                OsEncodingLib.encodeDaoParameters(daoParameters_, OsEncodingLib.DAO_PARAMETERS_STRUCT_VERSION);
            OsUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6, payload);
        }
    }

    //endregion -------------------------------------- Update instantly or through proposals
}
