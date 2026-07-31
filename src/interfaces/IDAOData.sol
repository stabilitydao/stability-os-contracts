// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISegment4} from "./ISegment4.sol";

/// @notice DAO related types
interface IDAOData is ISegment4 {
    enum LifecyclePhase {
        /// @notice Created (draft).
        DRAFT_0,

        /// @notice DAO ready to attract initial community
        INCEPTION_1,

        /// @notice Initial funding. Project met requirements; after SEED the DAO becomes real: non-custodial, tokenized shares, collective governance through voting.
        SEED_2,

        /// @notice Unsuccessful SEED campaign; collected funds are returned.
        SEED_FAILED_3,

        /// @notice Use of SEED funds to launch MVP / generate units.
        DEVELOPMENT_4,

        /// @notice TGE — token generation event for token liquidity and DAO development (optional).
        TGE_5,

        /// @notice Waiting period before vesting begins.
        LIVE_CLIFF_6,

        /// @notice Vesting period active.
        LIVE_VESTING_7,

        /// @notice Vesting completed — tokens fully distributed.
        LIVE_8,

        COUNT_LIFECYCLE_PHASES
    }

    enum DAOAction {
        UPDATE_IMAGES_0,
        UPDATE_SOCIALS_1,
        UPDATE_NAMING_2,
        UPDATE_UNITS_3,
        UPDATE_FUNDING_4,
        UPDATE_VESTING_5,
        UPDATE_DAO_PARAMETERS_6,
        UPDATE_SALT_7,
        UPDATE_DAO_CHAIN_SETTINGS_8,
        /// @notice Some action that should be approved as proposal and performed on another chain, see BridgedActions
        UPDATE_BRIDGED_DAO_9,
        UPDATE_GOVERNANCE_SETTINGS_10
    }

    /// @notice Funding types.
    enum FundingType {
        SEED_0,
        TGE_1,

        COUNT_FUNDING_TYPES
    }

    /// @notice Organization activities supported by OS.
    enum Activity {
        /// @notice Owner of Decentralized Finance protocols
        DEFI_0,

        /// @notice Searching of Maximum Extractable Value opportunities and submitting it to block builders.
        MEV_1,

        /// @notice Owner of Software as a Service business
        SAAS_2,

        /// @dev Total count of activities, must be the last enum value
        COUNT_ACTIVITY
    }

    enum VotingStatus {
        VOTING_0,
        APPROVED_1,
        REJECTED_2
    }

    /// @notice Images of tokens. Absolute or relative from stabilitydao/.github repo /os/ folder.
    struct DaoImages {
        string seedToken;
        string tgeToken;
        string token;
        string xToken;
        string daoToken;
        // Attention: Don't forget to increment OsEncodingLib.DAO_IMAGES_STRUCT_VERSION if you add new fields here
    }

    /// @notice Deployments of running DAO on blockchains.
    struct DaoDeploymentInfo {
        /// @notice Seed round receipt token.
        address seedToken;
        /// @notice TGE pre-sale receipt token.
        address tgeToken;
        /// @notice Main tradable DAO token.
        address token;
        /// @notice VE-tokenomics entry token.
        address xToken;
        /// @notice Staking contract.
        address staking;
        /// @notice Governance token.
        address daoToken;
        /// @notice Revenue utilization and distributing contract.
        address revenueRouter;
        /// @notice Accident recovery system contract.
        address recovery;
        /// @notice Set of vesting contracts (address of registry or single vesting contract).
        address[] vesting;
        /// @notice Bridge for Token.
        address tokenBridge;
        /// @notice Bridge for XToken.
        address xTokenBridge;
        /// @notice Bridge for Governance token.
        address daoTokenBridge;
    }

    /// @notice Vested Escrow period, days.
    struct DaoParameters {
        /// @notice Vested Escrow period, days.
        uint32 vePeriod;

        /// @notice Instant exit fee, decimals 1e5 (!), i.e. 50_000 = 50%   todo probably we should change implementation in xSTBL !!!!
        uint32 pvpFee;

        /// @notice Minimal power in chain to have voting rights, amount of staked tokens
        uint minPower;

        /// @notice Bribe share for Tokenomics Transactions (vested funds spending), percent. Decimals 1e5, i.e. 20_000 = 20%
        // todo: remove
        uint32 ttBribe;

        /// @notice Share of total DAO revenue going to accidents compensations, percent. Decimals 1e5, i.e. 20_000 = 20%
        uint32 recoveryShare;

        /// @notice Minimal total voting power (self and delegated) need to create a proposal, percent. Decimals 1e5, i.e. 20_000 = 20%
        // todo: remove
        uint proposalThreshold;

        /// @notice Total supply of the DAO token. This value cannot be changed after start of TGE
        // todo: move to Segment 3
        uint totalSupply;
        // Attention: Don't forget to increment OsEncodingLib.DAO_PARAMETERS_STRUCT_VERSION if you add new fields here
    }

    /// @notice Funding record for a round.
    struct Funding {
        /// @notice Funding type
        FundingType fundingType;

        /// @notice Start timestamp (seconds since unix epoch).
        uint64 start;

        /// @notice End timestamp (seconds since unix epoch).
        uint64 end;

        /// @notice Date of DAO launching (after TGE finishing, DAO token is deployed, etc)
        uint64 claim;

        /// @notice Minimum raise amount, USD decimals 18
        uint minRaise;

        /// @notice Maximum raise amount, USD decimals 18
        uint maxRaise;

        /// @notice Amount already raised, USD decimals 18
        uint raised;
        // Attention: Don't forget to increment OsEncodingLib.FUNDING_STRUCT_VERSION if you add new fields here
    }

    /// @notice Vesting allocation record.
    struct Vesting {
        /// @notice Short name of vesting allocation
        string name;

        /// @notice How must be spent
        string description;

        /// @notice Vesting supply, in percents. Decimals 1e5, i.e. 20_000 = 20%
        uint32 allocation;

        /// @notice Start timestamp
        uint64 start;

        /// @notice End timestamp
        uint64 end;
        // Attention: Don't forget to increment OsEncodingLib.VESTING_STRUCT_VERSION if you add new fields here
    }

    struct DaoNames {
        string symbol;
        string name;
    }

    struct Proposal {
        DAOAction action;

        /// @dev True if proposal requires validation by Host DAO before voting
        /// Typical rejection case: proposal contains invalid data that have collisions with exist data on other chains
        /// I.e. proposed salt is already used on the target chain
        bool validationRequired;

        /// @dev True if proposal requires voting by DAO members = instant update.
        /// Some proposals cannot be applied instantly because they require validation by admin
        bool votingRequired;

        /// @dev Status of proposal validation by admin
        ValidationStatus validationStatus;

        /// @dev Symbol of DAO to which the proposal is related
        string symbol;

        /// @notice Proposal creation timestamp
        uint64 created;

        VotingStatus status;

        /// @dev Proposal UID (unique per all DAOs)
        bytes32 id;

        /// @notice Hash of proposal payload
        bytes32 payloadHash;
    }

    struct DaoChainSettings {
        /// @notice The percentage of unit revenue to swap into the DAO’s main token and distribute as xToken, [0..100]
        uint8 bbRate;

        /// @notice GitHub organization (from socials) EVM multisig address
        address multisig;
    }

    struct GovernanceSettings {
        /// @notice Minimal total voting power (self and delegated) need to create a proposal, percent, decimals 1e5, i.e. 20_000 = 20%
        uint32 proposalThreshold;

        /// @notice Bribe share for Tokenomics Transactions (vested funds spending), percent  todo decimals?
        uint32 ttBribe;
    }

    /// @notice On-chain data of the Unit.
    struct UnitData {
        /// @notice Unique unit string id. For DeFi protocol its defiOrg:protocolKey.
        string unitId;

        /// @notice Blockchains where Unit deployed. Filled only for initial DAO chain Host instance.
        uint[] chainIds;

        /// @notice DAO UID of Unit Developer (Pool tasks solver)
        string developerUid;
    }

    /// @notice Status of proposal validation by Host DAO
    enum ValidationStatus {
        NONE_0,
        APPROVED_1,
        REJECTED_2
    }

    /// @notice Indices of all contracts that can be deployed by a DAO. The indices are used to pre-set salts
    enum ContractIndices {
        NOT_USED_0,
        SEED_TOKEN_1,
        TGE_TOKEN_2,
        TOKEN_3,
        X_TOKEN_4,
        DAO_TOKEN_5,
        STAKING_6,
        RECOVERY_7,
        TOKEN_BRIDGE_8,
        X_TOKEN_BRIDGE_9,
        DAO_TOKEN_BRIDGE_10,
        VESTING_1_11,
        VESTING_2_12,
        VESTING_3_13,
        VESTING_4_14,
        VESTING_5_15,
        VESTING_6_16,
        VESTING_7_17,
        VESTING_8_18,
        VESTING_9_19,
        VESTING_10_20,
        REVENUE_ROUTER_21,

        // add new indices here if necessary

        COUNT_CONTRACT_INDICES
    }

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

        // @notice Revenue generated by a Unit in assets {unitRevenueAssets}
        uint[] unitRevenue;

        /// @notice Assets in which revenue generated by a Unit is denominated.
        address[] unitRevenueAssets;

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

        /// @notice Deployed vesting contracts for vesting allocations. The same order as {vesting}
        address[] vestingContracts;

        /// @notice Settings of DAO Governance
        GovernanceSettings governanceSettings;

        /// @notice Deployer of a DAO have power only at DRAFT phase.
        address deployer;

        /// @notice Indices of all contracts that have not zero {salts}
        uint16[] saltContractIndices;

        /// @notice Salts of all contracts from {saltContractIndices}
        bytes32[] salts;

        /// @notice DAO custom metadata stored off-chain
        string metaDataLocation;
        // ---------------------------- All other segments are excluded here
        // SEGMENT 4: OFF-CHAIN emitted data
        // SEGMENT 5: OFF-CHAIN data on custom location
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
        string metaDataLocation;

        // ---------------------------- SEGMENT 4: OFF-CHAIN emitted data

        // @notice All emitted data (not stored on chain)
        UnitEmitData[] unitDataToEmit;
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
