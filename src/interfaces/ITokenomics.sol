// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDAOAgent} from "./IDAOAgent.sol";
import {IDAOUnit} from "./IDAOUnit.sol";

interface ITokenomics is IDAOAgent, IDAOUnit {

    enum LifecyclePhase {
        /// @notice Created (draft).
        DRAFT_0,

        /// @notice Initial funding. Project met requirements; after SEED the DAO becomes real: non-custodial, tokenized shares, collective governance through voting.
        SEED_1,

        /// @notice Unsuccessful SEED campaign; collected funds are returned.
        SEED_FAILED_2,

        /// @notice Use of SEED funds to launch MVP / generate units.
        DEVELOPMENT_3,

        /// @notice TGE — token generation event for token liquidity and DAO development (optional).
        TGE_4,

        /// @notice Waiting period before vesting begins.
        LIVE_CLIFF_5,

        /// @notice Vesting period active.
        LIVE_VESTING_6,

        /// @notice Vesting completed — tokens fully distributed.
        LIVE_7
    }

    enum DAOAction {
        UPDATE_IMAGES_0,
        UPDATE_SOCIALS_1,
        UPDATE_NAMING_2,
        UPDATE_UNITS_3,
        UPDATE_FUNDING_4,
        UPDATE_VESTING_5,
        UPDATE_DAO_PARAMETERS_6
    }

    /// @notice Funding types.
    enum FundingType {
        SEED_0,
        TGE_1
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
        BUILDER_3
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
        address vesting;
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
        uint16 pvpFee;

        /// @notice Minimal power in chain to have voting rights, amount of staked tokens
        uint minPower;

        /// @notice Bribe share for Tokenomics Transactions (vested funds spending), percent. Decimals 1e5, i.e. 20_000 = 20%
        uint16 ttBribe;

        /// @notice Share of total DAO revenue going to accidents compensations, percent. Decimals 1e5, i.e. 20_000 = 20%
        uint16 recoveryShare;

        /// @notice Minimal total voting power (self and delegated) need to create a proposal, percent. Decimals 1e5, i.e. 20_000 = 20%
        uint proposalThreshold;
    }

    /// @notice Funding record for a round.
    struct Funding {
        /// @notice Funding type
        FundingType fundingType;

        /// @notice Start timestamp (seconds since unix epoch).
        uint64 start;

        /// @notice End timestamp (seconds since unix epoch).
        uint64 end;

        /// @notice Minimum raise amount todo units
        uint minRaise;

        /// @notice Maximum raise amount todo units
        uint maxRaise;

        /// @notice Amount already raised todo units
        uint raised;

        /// @notice todo
        uint claim;
    }

    /// @notice Vesting allocation record.
    struct Vesting {
        /// @notice Short name of vesting allocation
        string name;

        /// @notice How must be spent
        string description;

        /// @notice Vesting supply. 10 == 10e18 TOKEN
        uint allocation;

        /// @notice Start timestamp
        uint64 start;

        /// @notice End timestamp
        uint64 end;
    }

    struct DaoNames {
        string symbol;
        string name;
    }

    struct Proposal {
        DAOAction action;

        string id;
        string daoSymbol;
        /// @notice Proposal creation timestamp
        uint64 created;
        VotingStatus status;

        /// @notice Proposal data as bytes
        /// @dev Actual data depends on {action}
        bytes payload;
    }

    /// @notice Tokenomics related grouped fields
    struct Tokenomics {
        /// @notice Fundraising rounds
        Funding[] funding;

        /// @notice Where initial deployment happened (chain id)
        uint256 initialChain;

        /// @notice Vesting allocations (optional)
        Vesting[] vesting;
    }

    /// @notice Full DAO info
    struct DaoData {
        /// @notice DAO lifecycle phase. Changes permissionless when next phase start timestamp reached.
        LifecyclePhase phase;

        /// @notice Tradeable interchain ERC-20 token symbol. Lowercased used as slug - unique ID of DAO in OS.
        string symbol;

        /// @notice Name of the DAO, used in token names. Without DAO word.
        string name;

        /// @notice Deployer of a DAO have power only at DRAFT phase.
        address deployer;

        /// @notice Community socials. Update by `OS.updateSocials`
        string[] socials;

        /// @notice Activities of the organization.
        Activity[] activity;

        /// @notice Images of tokens. Absolute or relative from repo /os/ folder.
        DaoImages images;

        /// @notice Deployments of running DAO on blockchains.
        DaoDeploymentInfo deployments;

        /// @notice Registered revenue generating units owned by the organization.
        UnitInfo[] units;

        /// @notice Operating agents managed by the organization.
        AgentInfo[] agents;

        /// @notice On-chain DAO parameters for tokenomics, governance and revenue sharing
        DaoParameters params;

        /// @notice Supply distribution and fundraising events + vesting + initial chain
        Tokenomics tokenomics;
    }
}

