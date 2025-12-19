// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OsEncodingLib} from "./OsEncodingLib.sol";
import {IOS} from "../../interfaces/IOS.sol";
import {ITokenomics, IDAOUnit} from "../../interfaces/ITokenomics.sol";
import {console} from "forge-std/console.sol";

/// @notice Basic data types, validation and update logic
library OsLib {
    // keccak256(abi.encode(uint(keccak256("erc7201:stability-os-contracts.OS")) - 1)) & ~bytes32(uint(0xff));
    bytes32 internal constant OS_STORAGE_LOCATION = 0; // todo

    //region -------------------------------------- Data types
    /// @notice Supply distribution and fundraising events.
    struct TokenomicsLocal {
        /// @notice Fundraising. Only funding types.
        /// @dev Actual funding data are stored in the mapping (to be able to extend list of Funding fields)
        ITokenomics.FundingType[] funding;

        /// @notice id of the chain where initial deployment became
        uint initialChain;

        /// @notice Vesting allocations (optional — may be empty). Count of registered vesting items.
        /// @dev Actual vesting data are stored in the mapping (to be able to extend list of Vesting fields)
        uint countVesting;
    }

    /// @notice DAO record.
    struct DaoDataLocal {
        /// @notice Tradeable interchain ERC-20 token symbol. Lowercased used as slug - unique ID of DAO in OS.
        string symbol;

        /// @notice Name of the DAO, used in token names. Without DAO word.
        string name;

        /// @notice Deployer of a DAO have power only at DRAFT phase.
        address deployer;

        /// @notice DAO lifecycle phase. Changes permissionless when next phase start timestamp reached.
        ITokenomics.LifecyclePhase phase;

        /// @notice Community socials. Update by `OS.updateSocials`
        string[] socials;

        /// @notice List of activities of the DAO
        ITokenomics.Activity[] activity;

        /// @notice Count of registered revenue generating units owned by the organization.
        /// @dev Actual units data are stored in the mapping (to be able to extend list of Unit fields)
        uint32 countUnits;

        /// @notice Count of registered operating agents managed by the organization.
        /// @dev Actual agent data are stored in the mapping (to be able to extend list of Agent fields)
        uint32 countAgents;
    }

    /// @notice It refers to daoUid instead of daoSymbol
    struct ProposalLocal {
        ITokenomics.DAOAction action;

        /// @notice Proposal creation timestamp
        uint64 created;
        ITokenomics.VotingStatus status;

        /// @notice Unique proposal id
        bytes32 id;
        uint daoUid;

        /// @notice Proposal data as bytes. Actual data depends on {action}
        bytes payload;
    }

    /// @custom:storage-location erc7201:stability.Recovery
    struct OsStorage {
        /// @notice Auto-increment internal id for DAOs.
        /// @dev All DAO have unique symbol but it can be changed. We need immutable unique id for various internal processes.
        uint daoCount;

        /// @notice Mapping from DAO symbol (changeable) to its unique id (immutable)
        mapping(string daoSymbol => uint daoUid) daoUids;

        /// @notice Full list of all used DAO symbols (on any chains)
        mapping(string daoSymbol => bool registered) usedSymbols;

        /// @notice Plain data of each registered DAO
        /// @dev Full DAO data is stored on initial chain only. Other chains have only records in {usedSymbols}
        mapping(uint daoUid => OsLib.DaoDataLocal) daos;

        /// @notice Parameters of each DAO
        mapping(uint daoUid => ITokenomics.DaoParameters) daoParameters;

        /// @notice Tokenomics of each DAO
        mapping(uint daoUid => OsLib.TokenomicsLocal) tokenomics;

        /// @notice Images (logo/banner) of each DAO
        mapping(uint daoUid => ITokenomics.DaoImages) daoImages;

        /// @notice All deployments of DAOs on different chains. Deployment ID is generated as hash of (daoUid, chainId)
        mapping(uint daoUid => ITokenomics.DaoDeploymentInfo) deployments;

        /// @notice Fundraising. FundingId is generated as hash of (daoUid, funding type)
        mapping(bytes32 fundingId => ITokenomics.Funding) funding;

        /// @notice Vesting allocations. Key is generated as hash of (daoUid, 0-index)
        mapping(bytes32 key => ITokenomics.Vesting) vesting;

        /// @notice Revenue generating units owned by the organization. Key is generated as hash of (daoUid, 0-index)
        /// @dev 0-index is in [0...DaoData.countUnits-1]
        mapping(bytes32 key => IDAOUnit.UnitInfo) units;

        /// @notice Operating agents managed by the organization. Key is generated as hash of (daoUid, 0-index)
        /// @dev 0-index is in [0...DaoData.countAgents-1]
        mapping(bytes32 key => ITokenomics.AgentInfo) agents;

        /// @notice All registered proposals. Proposal id is unique across all DAOs
        mapping(bytes32 proposalId => ProposalLocal) proposals;

        /// @notice List of ids of all proposals for each DAO in order
        mapping(uint daoUid => bytes32[] proposalIds) daoProposals;

        /// @notice 0 => Settings of the OS. Mapping is used to be able to add new fields to OSSettings later
        mapping(uint zero => IOS.OsSettings) osSettings;

        /// @notice 0 => Settings of the OS. Mapping is used to be able to add new fields to OsChainSettings later
        mapping(uint zero => IOS.OsChainSettings) osChainSettings;
    }

    //endregion -------------------------------------- Data types

    //region -------------------------------------- Actions
    function validate(
        DaoDataLocal memory dao,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) internal view {
        OsStorage storage $ = getOsStorage();
        IOS.OsSettings storage st = $.osSettings[0];

        _validateDaoData(dao, st);
        _validateParams(params, st);
        _validateFunding(funding, st);
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Validation logic

    /// @notice Ensure that DAO name is in the range [minNameLength, maxNameLength]
    function _validateDaoData(DaoDataLocal memory dao, IOS.OsSettings storage st) internal view {
        OsStorage storage $ = getOsStorage();
        _validateNaming(dao.name, dao.symbol, st);

        // todo validate activity
    }

    function _validateNaming(string memory name, string memory symbol, IOS.OsSettings storage st) internal view {
        OsStorage storage $ = getOsStorage();

        {
            uint len = bytes(name).length;
            require(len >= st.minNameLength && len <= st.maxNameLength, IOS.NameLength(len));
        }

        {
            uint len = bytes(symbol).length;
            require(len >= st.minSymbolLength && len <= st.maxSymbolLength, IOS.SymbolLength(len));

            require(!$.usedSymbols[symbol], IOS.SymbolNotUnique(symbol));
        }
    }

    /// @notice Validate DAO params according to OS settings
    function _validateParams(ITokenomics.DaoParameters memory params, IOS.OsSettings storage st) internal view {
        require(params.pvpFee >= st.minPvPFee && params.pvpFee <= st.maxPvPFee, IOS.PvPFee(params.pvpFee));
        require(params.vePeriod  >= st.minVePeriod && params.vePeriod <= st.maxVePeriod, IOS.VePeriod(params.vePeriod));
    }

    /// @notice Ensure that funding is not empty
    function _validateFunding(ITokenomics.Funding[] memory funding, IOS.OsSettings storage st) internal pure {
        require(funding.length != 0, IOS.NeedFunding());

        st; // todo

        // todo: check funding array has unique funding types
        // todo: check funding dates
        // todo: check funding raise goals
    }

    //endregion -------------------------------------- Validation logic

    //region -------------------------------------- Update logic

    /// @notice Update images (logo/banner) of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.DaoImages struct
    function updateImages(uint daoUid, bytes memory payload) internal {
        OsStorage storage $ = getOsStorage();

        ITokenomics.DaoImages memory images = OsEncodingLib.decodeDaoImages(payload);
        $.daoImages[daoUid] = images;

        emit IOS.DaoImagesUpdated($.daos[daoUid].symbol, images);
    }

    /// @notice Update socials of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded string[] array
    function updateSocials(uint daoUid, bytes memory payload) internal {
        OsStorage storage $ = getOsStorage();

        string[] memory socials = OsEncodingLib.decodeSocials(payload);
        $.daos[daoUid].socials = socials;

        emit IOS.DaoSocialsUpdated($.daos[daoUid].symbol, socials);
    }

    /// @notice Update revenue generating units of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.UnitInfo[] array
    function updateUnits(uint daoUid, bytes memory payload) internal {
        OsStorage storage $ = getOsStorage();

        ITokenomics.UnitInfo[] memory units = OsEncodingLib.decodeUnits(payload);
        uint32 countUnits = uint32(units.length);
        $.daos[daoUid].countUnits = countUnits;

        for (uint32 i = 0; i < countUnits; i++) {
            bytes32 key = getKey(daoUid, i);

            ITokenomics.UnitInfo storage unitInfo = $.units[key];
            unitInfo.unitId = units[i].unitId;
            unitInfo.name = units[i].name;
            unitInfo.status = units[i].status;
            unitInfo.unitType = units[i].unitType;
            unitInfo.revenueShare = units[i].revenueShare;
            unitInfo.emoji = units[i].emoji;
            unitInfo.api = units[i].api;
            for (uint j; j < units[i].ui.length; ++j) {
                unitInfo.ui.push(units[i].ui[j]);
            }
        }

        emit IOS.DaoUnitsUpdated($.daos[daoUid].symbol, units);
    }

    /// @notice Replace array of funding of the DAO by new one
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.Funding[] array
    function updateFunding(uint daoUid, bytes memory payload) internal {
        OsStorage storage $ = getOsStorage();

        ITokenomics.Funding[] memory listFunding = OsEncodingLib.decodeFunding(payload);
        require(listFunding.length != 0, IOS.NeedFunding());
        delete $.tokenomics[daoUid].funding;
        uint countFunding = listFunding.length;
        for (uint i = 0; i < countFunding; i++) {
            ITokenomics.Funding memory fundingItem = listFunding[i];
            bytes32 fundingId = getKey(daoUid, uint(fundingItem.fundingType));
            $.funding[fundingId] = fundingItem;
            $.tokenomics[daoUid].funding.push(fundingItem.fundingType);
        }

        emit IOS.DaoFundingUpdated($.daos[daoUid].symbol, listFunding);
    }

    /// @notice Update vesting allocations of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.Vesting[] array
    function updateVesting(uint daoUid, bytes memory payload) internal {
        OsStorage storage $ = getOsStorage();

        ITokenomics.Vesting[] memory vesting = OsEncodingLib.decodeVesting(payload);
        uint countVesting = vesting.length;
        $.tokenomics[daoUid].countVesting = countVesting;

        for (uint i = 0; i < countVesting; i++) {
            bytes32 key = getKey(daoUid, i);
            $.vesting[key] = vesting[i];
        }

        emit IOS.DaoVestingUpdated($.daos[daoUid].symbol, vesting);
    }

    /// @notice Update DAO naming (name and symbol)
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.DaoNames struct
    function updateNaming(uint daoUid, bytes memory payload) internal {
        OsStorage storage $ = getOsStorage();

        ITokenomics.DaoNames memory _daoNames = OsEncodingLib.decodeDaoNames(payload);

        string memory oldSymbol = $.daos[daoUid].symbol;
        delete $.usedSymbols[oldSymbol];

        $.daos[daoUid].symbol = _daoNames.symbol;
        $.daos[daoUid].name = _daoNames.name;

        // register new symbol
        $.usedSymbols[_daoNames.symbol] = true;

        emit IOS.DaoNamingUpdated(oldSymbol, _daoNames);
    }

    function updateDaoParameters(uint daoUid, bytes memory payload) internal {
        OsStorage storage $ = getOsStorage();

        ITokenomics.DaoParameters memory daoParameters_ = OsEncodingLib.decodeDaoParameters(payload);
        $.daoParameters[daoUid] = daoParameters_;

        emit IOS.DaoParametersUpdated($.daos[daoUid].symbol, daoParameters_);
    }

    //endregion -------------------------------------- Update logic

    //region -------------------------------------- Internal utils
    function getOsStorage() internal pure returns (OsStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := OS_STORAGE_LOCATION
        }
    }

    function getKey(uint daoUid, uint index) internal pure returns (bytes32) {
        return keccak256(abi.encode(daoUid, index));
    }

    //endregion -------------------------------------- Internal utils



}