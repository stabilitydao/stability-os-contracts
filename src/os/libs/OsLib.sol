// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOS} from "../../interfaces/IOS.sol";
import {ITokenomics, IDAOUnit} from "../../interfaces/ITokenomics.sol";

/// @notice Basic data types and constants for OS system. This library shouldn't depend on any other libraries.
library OsLib {
    // keccak256(abi.encode(uint(keccak256("erc7201:stability-os-contracts.OS")) - 1)) & ~bytes32(uint(0xff));
    bytes32 public constant OS_STORAGE_LOCATION = 0x5824966c3b02e13a929a59c47f974f2669cd3c16f7c9a1165b6eab024c64c500;

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

    /// @custom:storage-location erc7201:stability-os-contracts.OS
    struct OsStorage {
        /// @notice Internal counter of created DAOs. It's used to generate unique immutable id for each DAO.
        uint daoCount;

        // todo there is no way to enumerate all created DAO (or all used symbols). Probably it's not really necessary

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

    /// @dev All DAO have unique symbol but it can be changed. We need immutable unique id for various internal processes.
    function generateDaoUid(OsLib.OsStorage storage $) internal returns (uint) {
        uint count = $.daoCount + 1;
        $.daoCount = count;
        return uint(keccak256(abi.encodePacked(count, block.chainid)));
    }
    //endregion -------------------------------------- Internal utils
}
