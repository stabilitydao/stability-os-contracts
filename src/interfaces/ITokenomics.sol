// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDAOAgent} from "./IDAOAgent.sol";
import {IDAOUnit} from "./IDAOUnit.sol";
import {IDAOBuilder} from "./IDAOBuilder.sol";

interface ITokenomics is IDAOAgent, IDAOUnit, IDAOBuilder {

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
        LIVE_7,

        /// @notice Absorbed by another DAO on Stability OS.
        ABSORBED_8
    }

    /// @notice TODO Images of tokens. Absolute or relative from stabilitydao/.github repo /os/ folder.
    struct DaoImages {
        address seedToken;
        address tgeToken;
        address token;
        address xToken;
        address daoToken;
    }

    /// @notice Deployments of running DAO on blockchains.
    struct DaoDeployments {
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

        /// @notice Instant exit fee, percent
        uint16 pvpFee;

        /// @notice Minimal power in chain to have voting rights, amount of staked tokens
        uint256 minPower;

        /// @notice Bribe share for Tokenomics Transactions (vested funds spending), percent
        uint16 ttBribe;

        /// @notice Share of total DAO revenue going to accidents compensations, percent
        uint16 recoveryShare;

        /// @notice Minimal total voting power (self and delegated) need to create a proposal
        uint256 proposalThreshold;
    }

    /// @notice Funding types.
    enum FundingType {
        SEED_0,
        TGE_1
    }

    /// @notice Funding record for a round.
    struct Funding {
        /// @notice Funding type todo FundingType
        uint16 fundingType;

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

    /// @notice Supply distribution and fundraising events.
    struct Tokenomics {
        /// @notice Fundraising
        Funding[] funding;

        /// @notice id of the chain where initial deployment became
        uint initialChain;

        /// @notice Vesting allocations (optional — may be empty)
        Vesting[] vesting;
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

    /// @notice DAO record.
    struct DaoInfo {
        /// @notice DAO lifecycle phase (LifecyclePhase). Changes permissionless when next phase start timestamp reached.
        uint16 phase;

        /// @notice Activities of the organization, see Activity enum
        uint16[] activity;

        /// @notice Name of the DAO, used in token names. Without DAO word.
        string name;

        /// @notice Tradeable interchain ERC-20 token symbol. Lowercased used as slug - unique ID of DAO in OS.
        string symbol;

        /// @notice Community socials. Update by `OS.updateSocials`
        string[] socials;

        /// @notice Images of tokens. Absolute or relative from stabilitydao/.github repo /os/ folder.
        DaoImages images;

        /// @notice Deployed smart-contracts
        mapping(uint chain => DaoDeployments) deployments;

        /// @notice Revenue generating units owned by the organization.
        UnitInfo[] units;

        /// @notice Operating agents managed by the organization.
        AgentInfo[] agents;

        /// @notice On-chain DAO parameters for tokenomics, governance and revenue sharing
        DaoParameters params;

        /// @notice Supply distribution and fundraising events
        Tokenomics tokenomics;

        /// @notice Deployer of a DAO have power only at DRAFT phase.
        address deployer;

        /// @notice DAOs engaging BUILDER activity settings are stored off-chain
        BuilderActivity builderActivity;

        /// @notice Symbol of DAO who absorbed this DAO
        string absorberSymbol;
    }
}

