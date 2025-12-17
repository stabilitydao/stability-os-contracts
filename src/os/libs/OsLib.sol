// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../../interfaces/ITokenomics.sol";
import {IOS} from "../../interfaces/IOS.sol";
import {OsUpdateLib} from "./OsUpdateLib.sol";


library OsLib {
    // keccak256(abi.encode(uint(keccak256("erc7201:stability-os-contracts.OS")) - 1)) & ~bytes32(uint(0xff));
    bytes32 internal constant OS_STORAGE_LOCATION = 0; // todo

    //region -------------------------------------- Data types
    /// @notice Supply distribution and fundraising events.
    struct TokenomicsLocal {
        /// @notice Fundraising. Count of registered Funding items.
        /// @dev Actual funding data are stored in the mapping (to be able to extend list of Funding fields)
        uint countFunding;

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
        LifecyclePhase phase;

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

    struct BuilderActivityLocal {
        /// @notice Safe multisig account(s) of dev team.
        address[] multisig;

        /// @notice Tracked Github repositories where development going on.
        string[] repo;

        /// @notice Count of registered engineers.
        uint countWorkers;

        /// @notice Count of registered conveyors of unit components.
        uint countConveyors;

        /// @notice Count of registered pools of development tasks.
        uint countPools;

        /// @notice Count of registered total salaries / burn rates paid.
        uint countBurnRate;
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
        mapping(uint daoUid => DaoDataLocal) daos;

        /// @notice Parameters of each DAO
        mapping(uint daoUid => ITokenomics.DaoParameters) daoParameters;

        /// @notice Tokenomics of each DAO
        mapping(uint daoUid => TokenomicsLocal) tokenomics;

        /// @notice Images (logo/banner) of each DAO
        mapping(uint daoUid => ITokenomics.DaoImages) daoImages;

        /// @notice All deployments of DAOs on different chains. Deployment ID is generated as hash of (daoUid, chainId)
        mapping(uint daoUid => ITokenomics.DaoDeploymentInfo) deployments;

        /// @notice Builder activity info of each DAO todo do we need to use separate maps for Worker, Conveyor, etc to be able to extend them later?
        mapping(uint daoUid => BuilderActivityLocal) daoImages;

        /// @notice Engineers. Key is generated as hash of (daoUid, 0-index)
        mapping(bytes32 key => Worker) builderActivityWorkers;

        /// @notice Conveyors of unit components. Key is generated as hash of (daoUid, 0-index)
        mapping(bytes32 key => Conveyor) builderActivityConveyors;

        /// @notice Pools of development tasks. Key is generated as hash of (daoUid, 0-index)
        mapping(bytes32 key => Pool) builderActivityPools;

        /// @notice Total salaries / burn rates paid. Key is generated as hash of (daoUid, 0-index)
        mapping(bytes32 key => BurnRate) builderActivityBurnRate;

        /// @notice Fundraising. Key is generated as hash of (daoUid, 0-index)
        mapping(bytes32 key => ITokenomics.Funding) funding;

        /// @notice Vesting allocations. Key is generated as hash of (daoUid, 0-index)
        mapping(bytes32 key => ITokenomics.Vesting) vesting;

        /// @notice Activities of the organization. Key is generated as hash of (daoUid, 0-index)
        /// @dev 0-index is in [0...DaoData.countActivities-1]
        mapping(bytes32 key => ITokenomics.Activity) activities;

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

    //region -------------------------------------- View
    function getDAO(string calldata daoSymbol) external view returns (ITokenomics.DaoData memory) {
        OsStorage storage $ = getOsStorage();

        uint daoUid = $.daoUids[daoSymbol];

        ITokenomics.DaoData memory dest;

        { // ------------------- basic fields
            DaoDataLocal memory data = $.daos[daoUid];

            dest.symbol = data.symbol;
            dest.name = data.name;
            dest.deployer = data.deployer;
            dest.phase = data.phase;

            dest.socials = $.daos[daoUid].socials;
            dest.activity = $.daos[daoUid].activity;
        }

        { // ------------------- images, deployments, params
            dest.images = $.daoImages[daoUid];
            dest.deployments = $.deployments[daoUid];
            dest.params = $.daoParameters[daoUid];
            dest.builderActivity = $.builderActivity[daoUid];
        }

        { // ------------------- units
            uint len = uint(data.countUnits);
            dest.units = new ITokenomics.UnitInfo[](len);
            for (uint i; i < len; i++) {
                dest.units[i] = $.units[getKey(daoUid, i)];
            }
        }

        { // ------------------- agents
            uint len = uint(data.countAgents);
            dest.agents = new ITokenomics.AgentInfo[](len);
            for (uint i; i < len; i++) {
                dest.agents[i] = $.agents[getKey(daoUid, i)];
            }
        }

        { // ------------------- tokenomics
            TokenomicsLocal memory tokenomics = $.tokenomics[daoUid];

            {
                uint len = tokenomics.countFunding;
                dest.tokenomics.funding = new ITokenomics.Funding[](len);
                for (uint i; i < len; i++) {
                    dest.tokenomics.funding[i] = $.funding[getKey(daoUid, i)];
                }
            }
            dest.tokenomics.initialChain = tokenomics.initialChain;

            {
                uint len = tokenomics.countVesting;
                dest.tokenomics.vesting = new ITokenomics.Vesting[](len);
                for (uint i = 0; i < len; i++) {
                    dest.tokenomics.vesting[i] = $.vesting[getKey(daoUid, i)];
                }
            }
        }

        { // ------------------- builderActivity
            BuilderActivityLocal memory local = $.daoImages[daoUid];

            ITokenomics.BuilderActivity memory ba;

            ba.multisig = local.multisig;
            ba.repo = local.repo;

            // todo refactoring

            // workers
            uint wLen = local.countWorkers;
            ba.workers = new ITokenomics.Worker[](wLen);
            for (uint i; i < wLen; i++) {
                ba.workers[i] = $.builderActivityWorkers[getKey(daoUid, i)];
            }

            // conveyors
            uint cLen = local.countConveyors;
            ba.conveyors = new ITokenomics.Conveyor[](cLen);
            for (uint i; i < cLen; i++) {
                ba.conveyors[i] = $.builderActivityConveyors[getKey(daoUid, i)];
            }

            // pools
            uint pLen = local.countPools;
            ba.pools = new ITokenomics.Pool[](pLen);
            for (uint i = 0; i < pLen; i++) {
                ba.pools[i] = $.builderActivityPools[getKey(daoUid, i)];
            }

            // burn rates
            uint bLen = local.countBurnRate;
            ba.burnRate = new ITokenomics.BurnRate[](bLen);
            for (uint i = 0; i < bLen; i++) {
                ba.burnRate[i] = $.builderActivityBurnRate[getKey(daoUid, i)];
            }

            dest.builderActivity = ba;
        }

        return dest;
    }


    //endregion -------------------------------------- View

    //region -------------------------------------- Actions
    function createDAO(
        string calldata name,
        string calldata daoSymbol,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) internal {
        OsStorage storage $ = getOsStorage();

        require(!$.usedSymbols[daoSymbol], IOS.DaoSymbolAlreadyUsed());

        uint daoUid = ++$.daoCount;

        ITokenomics.DaoData memory daoData;
        daoData.name = name;
        daoData.symbol = daoSymbol;
        daoData.phase = ITokenomics.LifecyclePhase.DRAFT_0;
        daoData.countActivities = uint32(activity.length);
        daoData.deployer = msg.sender;

        OsUpdateLib.validate(daoData, activity, params, funding);

        // ------------------------- Save DAO data to the storage
        // we don't use viaIR=true in config so we cannot make direct assignment
        // $.daos[daoSymbol] = daoData;

        $.daoUids[daoSymbol] = daoUid;
        $.daos[daoUid] = daoData;
        $.daoParameters[daoUid] = params;
        $.tokenomics[daoUid].initialChain = block.chainid;
        $.tokenomics[daoUid].countFunding = funding.length;

        for (uint i = 0; i < activity.length; i++) {
            $.activities[getKey(daoUid, i)] = activity[i];
        }
        for (uint i = 0; i < funding.length; i++) {
            $.funding[getKey(daoUid, i)] = funding[i];
        }

        $.usedSymbols[daoSymbol] = true;

        // ------------------------- Notify about a newly created DAO
        emit IOS.DaoCreated(name, daoSymbol, activity, params, funding);

        _sendCrossChainMessage(IOS.CrossChainMessages.NEW_DAO_SYMBOL_0, daoSymbol);
    }

    //endregion -------------------------------------- Actions


    //region -------------------------------------- Internal logic
    function _sendCrossChainMessage(IOS.CrossChainMessages kind, string memory daoSymbol) internal pure {
        kind;
        daoSymbol;
        // todo
    }
    //endregion -------------------------------------- Internal logic

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