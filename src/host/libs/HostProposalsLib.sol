// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHost} from "../../interfaces/IHost.sol";
import {ITokenomics} from "../../interfaces/ITokenomics.sol";
import {HostLib} from "./HostLib.sol";
import {HostEncodingLib} from "./HostEncodingLib.sol";
import {HostUpdateLib} from "./HostUpdateLib.sol";

/// @notice Library with proposal related functions
library HostProposalsLib {
    /// @notice Receive voting results from voting module and execute proposal if approved
    function receiveVotingResults(bytes32 proposalId, bool succeed) external {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        HostLib.ProposalLocal storage p = $.proposals[proposalId];

        require(p.daoUid != 0, IHost.IncorrectProposal());
        require(p.status == ITokenomics.VotingStatus.VOTING_0, IHost.AlreadyReceived());

        p.status = succeed ? ITokenomics.VotingStatus.APPROVED_1 : ITokenomics.VotingStatus.REJECTED_2;

        ITokenomics.DAOAction action = p.action;
        if (succeed) {
            if (action == ITokenomics.DAOAction.UPDATE_IMAGES_0) {
                HostUpdateLib.updateImages(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_SOCIALS_1) {
                HostUpdateLib.updateSocials(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_UNITS_3) {
                HostUpdateLib.updateUnits(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_FUNDING_4) {
                HostUpdateLib.updateFunding(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_VESTING_5) {
                HostUpdateLib.updateVesting(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_NAMING_2) {
                HostUpdateLib.updateNaming(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6) {
                HostUpdateLib.updateDaoParameters(p.daoUid, p.payload);
            } else {
                // todo other actions
                revert IHost.NonImplemented();
            }
        }
    }

    //region -------------------------------------- Update instantly or through proposals
    function _beforeUpdate(string memory daoSymbol)
        internal
        view
        returns (HostLib.OsStorage storage $, uint daoUid, bool instantExecute, ITokenomics.LifecyclePhase phase)
    {
        $ = HostLib.getOsStorage();
        daoUid = $.daoUids[daoSymbol];
        phase = $.daos[daoUid].phase;
        require(daoUid != 0, IHost.IncorrectDao());
        instantExecute = phase == ITokenomics.LifecyclePhase.DRAFT_0;
        if (instantExecute) {
            require($.daos[daoUid].deployer == msg.sender, IHost.YouAreNotOwnerOf(daoSymbol));
        }
    }

    /// @notice Update/create proposal to update implementations of the DAO contracts
    function updateImages(string memory daoSymbol, ITokenomics.DaoImages memory images) external {
        (, uint daoUid, bool instantExecute,) = _beforeUpdate(daoSymbol);

        if (instantExecute) {
            HostUpdateLib.updateImages(daoUid, images);
        } else {
            bytes memory payload = HostEncodingLib.encodeDaoImages(images, HostEncodingLib.DAO_IMAGES_STRUCT_VERSION);
            HostUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_IMAGES_0, payload);
        }
    }

    /// @notice Update/create proposal to update list of socials of the DAO
    function updateSocials(string memory daoSymbol, string[] memory socials) external {
        (, uint daoUid, bool instantExecute,) = _beforeUpdate(daoSymbol);

        if (instantExecute) {
            HostUpdateLib.updateSocials(daoUid, socials);
        } else {
            bytes memory payload = HostEncodingLib.encodeSocials(socials);
            HostUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_SOCIALS_1, payload);
        }
    }

    /// @notice Update/create proposal to update tokenomics units of the DAO
    function updateUnits(string memory daoSymbol, ITokenomics.UnitInfo[] memory units) external {
        (, uint daoUid, bool instantExecute,) = _beforeUpdate(daoSymbol);

        if (instantExecute) {
            HostUpdateLib.updateUnits(daoUid, units);
        } else {
            bytes memory payload = HostEncodingLib.encodeUnits(units, HostEncodingLib.UNIT_STRUCT_VERSION);
            HostUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_UNITS_3, payload);
        }
    }

    /// @notice Update/create proposal to update funding rounds of the DAO
    function updateFunding(string memory daoSymbol, ITokenomics.Funding memory funding) external {
        (HostLib.OsStorage storage $, uint daoUid, bool instantExecute, ITokenomics.LifecyclePhase phase) =
            _beforeUpdate(daoSymbol);

        HostUpdateLib._validateFunding(phase, funding, $.osSettings[0]);

        if (instantExecute) {
            HostUpdateLib.updateFunding(daoUid, funding);
        } else {
            bytes memory payload = HostEncodingLib.encodeFunding(funding, HostEncodingLib.FUNDING_STRUCT_VERSION);
            HostUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_FUNDING_4, payload);
        }
    }

    /// @notice Update/create proposal to update vesting schedules of the DAO
    function updateVesting(string memory daoSymbol, ITokenomics.Vesting[] memory vesting) external {
        (HostLib.OsStorage storage $, uint daoUid, bool instantExecute, ITokenomics.LifecyclePhase phase) =
            _beforeUpdate(daoSymbol);

        HostUpdateLib._validateVestingList(phase, vesting, $.osSettings[0]);

        if (instantExecute) {
            HostUpdateLib.updateVesting(daoUid, vesting);
        } else {
            bytes memory payload = HostEncodingLib.encodeVesting(vesting, HostEncodingLib.VESTING_STRUCT_VERSION);
            HostUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_VESTING_5, payload);
        }
    }

    /// @notice Update/create proposal to update DAO naming (name and symbol)
    function updateNaming(string memory daoSymbol, ITokenomics.DaoNames memory daoNames_) external {
        (HostLib.OsStorage storage $, uint daoUid, bool instantExecute,) = _beforeUpdate(daoSymbol);

        HostUpdateLib._validateNaming(daoNames_.name, daoNames_.symbol, $.osSettings[0]);

        if (instantExecute) {
            HostUpdateLib.updateNaming(daoUid, daoNames_);
        } else {
            bytes memory payload = HostEncodingLib.encodeDaoNames(daoNames_, HostEncodingLib.DAO_NAMES_STRUCT_VERSION);
            HostUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_NAMING_2, payload);
        }
    }

    /// @notice Update/create proposal to update on-chain DAO parameters
    function updateDaoParameters(string memory daoSymbol, ITokenomics.DaoParameters memory daoParameters_) external {
        (HostLib.OsStorage storage $, uint daoUid, bool instantExecute,) = _beforeUpdate(daoSymbol);

        HostUpdateLib._validateDaoParameters(daoParameters_, $.osSettings[0]);

        if (instantExecute) {
            HostUpdateLib.updateDaoParameters(daoUid, daoParameters_);
        } else {
            bytes memory payload =
                HostEncodingLib.encodeDaoParameters(daoParameters_, HostEncodingLib.DAO_PARAMETERS_STRUCT_VERSION);
            HostUpdateLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6, payload);
        }
    }

    //endregion -------------------------------------- Update instantly or through proposals
}
