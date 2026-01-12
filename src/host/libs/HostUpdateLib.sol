// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostEncodingLib} from "./HostEncodingLib.sol";
import {IHost} from "../../interfaces/IHost.sol";
import {ITokenomics} from "../../interfaces/ITokenomics.sol";
import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {HostLib} from "./HostLib.sol";

/// @notice Basic data types and constants for OS system.
library HostUpdateLib {
    //region -------------------------------------- Actions
    function validate(
        HostLib.DaoDataLocal memory dao,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) internal view {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        IHost.OsSettings storage st = $.osSettings[0];

        _validateDaoData(dao, st);
        _validateDaoParameters(params, st);
        _validateFundingList(funding, st);
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Validation logic

    /// @notice Ensure that DAO name is in the range [minNameLength, maxNameLength]
    function _validateDaoData(HostLib.DaoDataLocal memory dao, IHost.OsSettings storage st) internal view {
        _validateNaming(dao.name, dao.symbol, st);

        // todo validate activity
    }

    function _validateNaming(string memory name, string memory symbol, IHost.OsSettings storage st) internal view {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        {
            uint len = bytes(name).length;
            require(len >= st.minNameLength && len <= st.maxNameLength, IHost.NameLength(len));
        }

        {
            uint len = bytes(symbol).length;
            require(len >= st.minSymbolLength && len <= st.maxSymbolLength, IHost.SymbolLength(len));

            require(!$.usedSymbols[symbol], IHost.SymbolNotUnique(symbol));
        }
    }

    /// @notice Validate DAO params according to OS settings
    function _validateDaoParameters(ITokenomics.DaoParameters memory params, IHost.OsSettings storage st) internal view {
        require(params.pvpFee >= st.minPvPFee && params.pvpFee <= st.maxPvPFee, IHost.PvPFee(params.pvpFee));
        require(params.vePeriod >= st.minVePeriod && params.vePeriod <= st.maxVePeriod, IHost.VePeriod(params.vePeriod));
    }

    /// @notice Ensure that funding is not empty
    function _validateFundingList(ITokenomics.Funding[] memory funding, IHost.OsSettings storage st) internal pure {
        require(funding.length != 0, IHost.NeedFunding());

        st; // todo

        // todo: check funding array has unique funding types
        // todo: check funding dates
        // todo: check funding raise goals
    }

    function _validateFunding(
        ITokenomics.LifecyclePhase phase,
        ITokenomics.Funding memory funding,
        IHost.OsSettings storage st
    ) internal pure {
        if (funding.fundingType == ITokenomics.FundingType.SEED_0) {
            require(phase == ITokenomics.LifecyclePhase.DRAFT_0, IHost.TooLateToUpdateSuchFunding());
        }

        if (funding.fundingType == ITokenomics.FundingType.TGE_1) {
            require(
                phase == ITokenomics.LifecyclePhase.DRAFT_0 || phase == ITokenomics.LifecyclePhase.SEED_1
                    || phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3,
                IHost.TooLateToUpdateSuchFunding()
            );
        }

        st; // todo
        // todo check min round duration
        // todo check max round duration
        // todo check start date delay
        // todo check min amount
        // todo check max amount
    }

    function _validateVestingList(
        ITokenomics.LifecyclePhase phase,
        ITokenomics.Vesting[] memory vesting,
        IHost.OsSettings storage st
    ) internal pure {
        require(
            phase != ITokenomics.LifecyclePhase.LIVE_CLIFF_5 && phase != ITokenomics.LifecyclePhase.LIVE_VESTING_6
                && phase != ITokenomics.LifecyclePhase.LIVE_7,
            IHost.TooLateToUpdateVesting()
        );

        uint len = vesting.length;
        for (uint i; i < len; ++i) {
            // todo check vesting consistency
            st;
        }
    }

    //endregion -------------------------------------- Validation logic

    //region -------------------------------------- Proposal logic

    /// @notice Create new proposal
    /// @param daoUid Unique id of the DAO
    /// @param action Action type of the proposal
    /// @param payload Encoded proposal data
    /// @return proposalId Id of the created proposal. It is unique across all DAOs
    function proposeAction(uint daoUid, ITokenomics.DAOAction action, bytes memory payload) internal returns (bytes32) {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        // todo check for initial chain
        // todo get user power
        // todo check proposalThreshold
        // todo validate payload

        bytes32 proposalId = _createProposalId(daoUid, action, payload);

        HostLib.ProposalLocal storage proposal = $.proposals[proposalId];
        proposal.daoUid = daoUid;
        proposal.action = action;
        proposal.created = uint64(block.timestamp);
        proposal.status = ITokenomics.VotingStatus.VOTING_0;
        proposal.id = proposalId;
        proposal.payload = payload;

        $.daoProposals[daoUid].push(proposalId);

        return proposalId;
    }

    function _createProposalId(
        uint daoUid,
        ITokenomics.DAOAction action,
        bytes memory payload
    ) internal view returns (bytes32) {
        return keccak256(abi.encode(daoUid, HostLib.getOsStorage().daoProposals[daoUid].length, action, payload));
    }

    //endregion -------------------------------------- Proposal logic

    //region -------------------------------------- Update logic

    /// @notice Update images (logo/banner) of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.DaoImages struct
    function updateImages(uint daoUid, bytes memory payload) internal {
        ITokenomics.DaoImages memory images = HostEncodingLib.decodeDaoImages(payload);
        updateImages(daoUid, images);
    }

    function updateImages(uint daoUid, ITokenomics.DaoImages memory images) internal {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        $.daoImages[daoUid] = images;
        emit IHost.DaoImagesUpdated($.daos[daoUid].symbol, images);
    }

    /// @notice Update socials of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded string[] array
    function updateSocials(uint daoUid, bytes memory payload) internal {
        string[] memory socials = HostEncodingLib.decodeSocials(payload);
        updateSocials(daoUid, socials);
    }

    function updateSocials(uint daoUid, string[] memory socials) internal {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        $.daos[daoUid].socials = socials;
        emit IHost.DaoSocialsUpdated($.daos[daoUid].symbol, socials);
    }

    /// @notice Update revenue generating units of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.UnitInfo[] array
    function updateUnits(uint daoUid, bytes memory payload) internal {
        ITokenomics.UnitInfo[] memory units = HostEncodingLib.decodeUnits(payload);
        updateUnits(daoUid, units);
    }

    function updateUnits(uint daoUid, ITokenomics.UnitInfo[] memory units) internal {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        // todo take prices for unit creation

        uint32 countUnits = uint32(units.length);
        uint32 oldCountUnits = $.daos[daoUid].countUnits;
        $.daos[daoUid].countUnits = countUnits;

        for (uint32 i = 0; i < countUnits; i++) {
            bytes32 key = HostLib.getKey(daoUid, i);

            ITokenomics.UnitInfo storage unitInfo = $.units[key];
            unitInfo.unitId = units[i].unitId;
            unitInfo.name = units[i].name;
            unitInfo.status = units[i].status;
            unitInfo.unitType = units[i].unitType;
            unitInfo.revenueShare = units[i].revenueShare;
            unitInfo.emoji = units[i].emoji;

            delete unitInfo.api;
            delete unitInfo.ui;

            unitInfo.api = units[i].api;
            for (uint j; j < units[i].ui.length; ++j) {
                unitInfo.ui.push(units[i].ui[j]);
            }
        }

        // delete old units if new list is smaller
        for (uint32 i = countUnits; i < oldCountUnits; i++) {
            bytes32 key = HostLib.getKey(daoUid, i);
            delete $.units[key];
        }

        emit IHost.DaoUnitsUpdated($.daos[daoUid].symbol, units);
    }

    /// @notice Replace array of funding of the DAO by new one
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.Funding[] array
    function updateFunding(uint daoUid, bytes memory payload) internal {
        ITokenomics.Funding memory newFunding = HostEncodingLib.decodeFunding(payload);
        updateFunding(daoUid, newFunding);
    }

    function updateFunding(uint daoUid, ITokenomics.Funding memory newFunding) internal {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        ITokenomics.FundingType[] memory listFunding = $.tokenomics[daoUid].funding;

        // slither-disable-next-line uninitialized-local
        bool updated;

        for (uint i; i < listFunding.length; i++) {
            if (listFunding[i] == newFunding.fundingType) {
                updated = true;
                break;
            }
        }
        if (!updated) {
            $.tokenomics[daoUid].funding.push(newFunding.fundingType);
        }

        bytes32 fundingId = HostLib.getKey(daoUid, uint(newFunding.fundingType));
        $.funding[fundingId] = newFunding;

        emit IHost.DaoFundingUpdated($.daos[daoUid].symbol, newFunding);
    }

    /// @notice Update vesting allocations of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.Vesting[] array
    function updateVesting(uint daoUid, bytes memory payload) internal {
        ITokenomics.Vesting[] memory vesting = HostEncodingLib.decodeVesting(payload);
        updateVesting(daoUid, vesting);
    }

    function updateVesting(uint daoUid, ITokenomics.Vesting[] memory vesting) internal {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        uint countVesting = vesting.length;
        $.tokenomics[daoUid].countVesting = countVesting;

        for (uint i = 0; i < countVesting; i++) {
            bytes32 key = HostLib.getKey(daoUid, i);
            $.vesting[key] = vesting[i];
        }

        emit IHost.DaoVestingUpdated($.daos[daoUid].symbol, vesting);
    }

    /// @notice Update DAO naming (name and symbol)
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.DaoNames struct
    function updateNaming(uint daoUid, bytes memory payload) internal {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        ITokenomics.DaoNames memory _daoNames = HostEncodingLib.decodeDaoNames(payload);

        // todo we must validate if the new symbol is not used already
        // todo there is following case: X exists, X decides to change name to Y, Y is created while X voting is in progress, X cannot change name to Y
        require(!$.usedSymbols[_daoNames.symbol], IHost.SymbolNotUnique(_daoNames.symbol));

        updateNaming(daoUid, _daoNames);
    }

    function updateNaming(uint daoUid, ITokenomics.DaoNames memory daoNames_) internal {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        string memory oldSymbol = $.daos[daoUid].symbol;
        delete $.usedSymbols[oldSymbol];
        delete $.daoUids[oldSymbol];

        $.daos[daoUid].symbol = daoNames_.symbol;
        $.daos[daoUid].name = daoNames_.name;

        // register new symbol
        $.usedSymbols[daoNames_.symbol] = true;
        $.daoUids[daoNames_.symbol] = daoUid;

        emit IHost.DaoNamingUpdated(oldSymbol, daoNames_);

        HostCrossChainLib.sendMessageUpdateSymbol(oldSymbol, daoNames_.symbol);
    }

    function updateDaoParameters(uint daoUid, bytes memory payload) internal {
        ITokenomics.DaoParameters memory _daoParameters = HostEncodingLib.decodeDaoParameters(payload);
        updateDaoParameters(daoUid, _daoParameters);
    }

    function updateDaoParameters(uint daoUid, ITokenomics.DaoParameters memory daoParameters_) internal {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        $.daoParameters[daoUid] = daoParameters_;
        emit IHost.DaoParametersUpdated($.daos[daoUid].symbol, daoParameters_);
    }

    //endregion -------------------------------------- Update logic
}
