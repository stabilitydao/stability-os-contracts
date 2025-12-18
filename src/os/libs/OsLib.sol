// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../../interfaces/ITokenomics.sol";
import {IOS} from "../../interfaces/IOS.sol";
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
        mapping(bytes32 key => ITokenomics.UnitInfo) units;

        /// @notice Operating agents managed by the organization. Key is generated as hash of (daoUid, 0-index)
        /// @dev 0-index is in [0...DaoData.countAgents-1]
        mapping(bytes32 key => ITokenomics.AgentInfo) agents;

        /// @notice All registered proposals. Proposal Id is generated as hash of (daoUid, proposalId)
        mapping(bytes32 proposalUid => ITokenomics.Proposal) proposals;

        /// @notice List of all proposals for each DAO, proposalId is a string unique for the given DAO
        mapping(uint daoUid => string[] proposalIds) daoProposals;

        /// @notice 0 => Settings of the OS. Mapping is used to be able to add new fields to OSSettings later
        mapping(uint zero => IOS.OsSettings) osSettings;

        // todo mapping to store chain-depended data, i.e exchange asset address
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

    //region -------------------------------------- Logic

    /// @notice Ensure that DAO name is in the range [minNameLength, maxNameLength]
    function _validateDaoData(DaoDataLocal memory dao, IOS.OsSettings storage st) internal view {
        OsStorage storage $ = getOsStorage();

        {
            uint len = bytes(dao.name).length;
            require(len >= st.minNameLength && len <= st.maxNameLength, IOS.NameLength(len));
        }

        {
            uint len = bytes(dao.symbol).length;
            require(len >= st.minSymbolLength && len <= st.maxSymbolLength, IOS.SymbolLength(len));

            require(!$.usedSymbols[dao.symbol], IOS.SymbolNotUnique(dao.symbol));
        }

        // todo validate activity
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

    //endregion -------------------------------------- Logic

    //region -------------------------------------- Internal utils
    function getOsStorage() internal pure returns (OsStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := OS_STORAGE_LOCATION
        }
    }
    //endregion -------------------------------------- Internal utils



}