// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ITokenomics {
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
        DEFI_PROTOCOL_OPERATOR_0,

        /// @notice Owner of Software as a Service business
        SAAS_OPERATOR_1,

        /// @notice Searching of Maximum Extractable Value opportunities and submitting it to block builders.
        MEV_SEARCHER_2,

        /// @notice BUILDER is a team of engineers managed by DAOs.
        BUILDER_3,

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

        /// @notice Instant exit fee, decimals 1e4 (!), i.e. 50_00 = 50%             todo we have different decimals here, probably we should change implementation in xSTBL !!!!
        uint32 pvpFee;

        /// @notice Minimal power in chain to have voting rights, amount of staked tokens
        uint minPower;

        /// @notice Bribe share for Tokenomics Transactions (vested funds spending), percent. Decimals 1e5, i.e. 20_000 = 20%
        uint32 ttBribe;

        /// @notice Share of total DAO revenue going to accidents compensations, percent. Decimals 1e5, i.e. 20_000 = 20%
        uint32 recoveryShare;

        /// @notice Minimal total voting power (self and delegated) need to create a proposal, percent. Decimals 1e5, i.e. 20_000 = 20%
        uint proposalThreshold;

        /// @notice Total supply of the DAO token. This value cannot be changed after start of TGE
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
        ITokenomics.ValidationStatus validationStatus;

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
}

