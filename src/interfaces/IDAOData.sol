// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDAOMetadata} from "./IDAOMetadata.sol";
import {ITokenomicsAddons} from "./ITokenomicsAddons.sol";
import {ITokenomics} from "./ITokenomics.sol";

/// @notice Various variants of DAO data
interface IDAOData is ITokenomics, ITokenomicsAddons, IDAOMetadata {
    /// @notice DAO data available on-chain for users
    struct DaoData {
        // ---------------------------- SEGMENT 1: ON-CHAIN on all chains where Host deployed

        /// @notice Tradeable interchain ERC-20 token symbol. Lowercased used as slug - unique ID of DAO in OS.
        /// While token symbol is SYM then additional DAO tokens symbols are:
        /// seedSYM, saleSYM, xSYM, SYM_DAO
        string symbol;

        // ---------------------------- SEGMENT 2: ON-CHAIN on chains where DAO bridged
        /// @notice Unique ID of DAO (unique globally for all chains)
        uint uid;

        /// @notice Name of the DAO, used in token names. Without DAO word.
        string name;

        /// @notice DAO lifecycle phase. Changes permissionless when next phase start timestamp reached.
        LifecyclePhase phase;

        /// @notice Deployments of running DAO on blockchains.
        DaoDeploymentInfo deployments;

        /// @notice Settings of DAO for current chain. This is the only place to save settings of DAO for chains.
        DaoChainSettings chainSettings;

        /// @notice IDs of Units running on current chain
        string[] unitIds;

        /// @notice On-chain DAO parameters for tokenomics and revenue sharing
        DaoParameters params;

        // ---------------------------- SEGMENT 3: ON-CHAIN on initial chain of DAO

        /// @notice Where initial deployment became
        uint initialChain;

        /// @notice Community socials. Update by `Host.updateSocials`
        string[] socials;

        /// @notice Activities of the organization.
        Activity[] activity;

        /// @notice Images of tokens. Absolute or relative from repo /os/ folder.
        DaoImages images;

        /// @notice Registered revenue generating units owned by the organization.
        /// @dev There is not UnitMetaData here because it's stored off-chain only.
        UnitData[] units;

        /// @notice Fundraising rounds
        Funding[] funding;

        /// @notice Vesting allocations (optional)
        Vesting[] vesting;

        /// @notice Settings of DAO Governance
        GovernanceSettings governanceSettings;

        /// @notice Deployer of a DAO have power only at DRAFT phase.
        address deployer;

        /// @notice DAO custom metadata stored off-chain
        string daoMetaDataLocation;
        // ---------------------------- All other segments are excluded here
        // SEGMENT 4: OFF-CHAIN emitted data
        // SEGMENT 5: OFF-CHAIN custom data managed by DAO
        // SEGMENT 6: API data of DAO
    }

    /// @notice DAO data to be input when creating DAO
    struct DaoDataInput {
        // ---------------------------- SEGMENT 1: ON-CHAIN on all chains where Host deployed

        /// @notice Tradeable interchain ERC-20 token symbol. Lowercased used as slug - unique ID of DAO in OS.
        /// While token symbol is SYM then additional DAO tokens symbols are:
        /// seedSYM, saleSYM, xSYM, SYM_DAO
        string symbol;

        // ---------------------------- SEGMENT 2: ON-CHAIN on chains where DAO bridged
        /// @notice Name of the DAO, used in token names. Without DAO word.
        string name;

        /// @notice DAO lifecycle phase. Changes permissionless when next phase start timestamp reached.
        LifecyclePhase phase;

        /// @notice Deployments of running DAO on blockchains.
        DaoDeploymentInfo deployments;

        /// @notice Settings of DAO for current chain. This is the only place to save settings of DAO for chains.
        DaoChainSettings chainSettings;

        /// @notice IDs of Units running on current chain
        string[] unitIds;

        /// @notice On-chain DAO parameters for tokenomics and revenue sharing
        DaoParameters params;

        // ---------------------------- SEGMENT 3: ON-CHAIN on initial chain of DAO

        /// @notice Community socials. Update by `Host.updateSocials`
        string[] socials;

        /// @notice Activities of the organization.
        Activity[] activity;

        /// @notice Images of tokens. Absolute or relative from repo /os/ folder.
        DaoImages images;

        /// @notice Registered revenue generating units owned by the organization.
        /// @dev There is not UnitMetaData here because it's stored off-chain only.
        UnitDataInput[] units;

        /// @notice Fundraising rounds
        Funding[] funding;

        /// @notice Vesting allocations (optional)
        Vesting[] vesting;

        /// @notice Settings of DAO Governance
        GovernanceSettings governanceSettings;

        /// @notice Deployer of a DAO have power only at DRAFT phase.
        address deployer;

        /// @notice DAO custom metadata stored off-chain
        string daoMetaDataLocation;

        // ---------------------------- SEGMENT 4: OFF-CHAIN emitted data

        // @notice All emitted data (not stored on chain)
        UnitMetaData[] unitsMetaData;
    }

    /// @notice On-chain data of the Unit.
    struct UnitDataInput {
        /// @notice Unique unit string id. For DeFi protocol its defiOrg:protocolKey.
        string unitId;

        /// @notice DAO UID of Unit Developer (Pool tasks solver)
        string developerUid;
        // Attention: Don't forget to increment OsEncodingLib.UNIT_STRUCT_VERSION if you add new fields here
    }
}
