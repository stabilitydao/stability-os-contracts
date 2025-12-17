// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../../interfaces/ITokenomics.sol";
import {IOS} from "../../interfaces/IOS.sol";
import {OsLib} from "./OsLib.sol";
import {console} from "forge-std/console.sol";

library OsActionsLib {
    //region -------------------------------------- View
    function getDAO(string calldata daoSymbol) external view returns (ITokenomics.DaoData memory) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();

        uint daoUid = $.daoUids[daoSymbol];

        ITokenomics.DaoData memory dest;
        OsLib.DaoDataLocal memory data = $.daos[daoUid];

        { // ------------------- basic fields

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
        }

        // ------------------- units
        dest.units = new ITokenomics.UnitInfo[](data.countUnits);
        for (uint i; i < data.countUnits; i++) {
            dest.units[i] = $.units[getKey(daoUid, i)];
        }

        // ------------------- agents
        dest.agents = new ITokenomics.AgentInfo[](data.countAgents);
        for (uint i; i < data.countAgents; i++) {
            dest.agents[i] = $.agents[getKey(daoUid, i)];
        }

        { // ------------------- tokenomics
            OsLib.TokenomicsLocal memory tokenomics = $.tokenomics[daoUid];
            dest.tokenomics.initialChain = tokenomics.initialChain;

            dest.tokenomics.funding = new ITokenomics.Funding[](tokenomics.countFunding);
            for (uint i; i < tokenomics.countFunding; i++) {
                dest.tokenomics.funding[i] = $.funding[getKey(daoUid, i)];
            }

            dest.tokenomics.vesting = new ITokenomics.Vesting[](tokenomics.countVesting);
            for (uint i; i < tokenomics.countVesting; i++) {
                dest.tokenomics.vesting[i] = $.vesting[getKey(daoUid, i)];
            }
        }

        { // ------------------- builderActivity
            OsLib.BuilderActivityLocal memory local = $.builderActivity[daoUid];

            ITokenomics.BuilderActivity memory ba;
            ba.multisig = local.multisig;
            ba.repo = local.repo;

            ba.workers = new ITokenomics.Worker[](local.countWorkers);
            for (uint i; i < local.countWorkers; i++) {
                ba.workers[i] = $.builderActivityWorkers[getKey(daoUid, i)];
            }

            ba.conveyors = new ITokenomics.Conveyor[](local.countConveyors);
            for (uint i; i < local.countConveyors; i++) {
                ba.conveyors[i] = $.builderActivityConveyors[getKey(daoUid, i)];
            }

            ba.pools = new ITokenomics.Pool[](local.countPools);
            for (uint i; i < local.countPools; i++) {
                ba.pools[i] = $.builderActivityPools[getKey(daoUid, i)];
            }

            ba.burnRate = new ITokenomics.BurnRate[](local.countBurnRate);
            for (uint i; i < local.countBurnRate; i++) {
                ba.burnRate[i] = $.builderActivityBurnRate[getKey(daoUid, i)];
            }

            dest.builderActivity = ba;
        }

        return dest;
    }

    function getSettings() external view returns (IOS.OsSettings memory) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        return $.osSettings[0];
    }
    //endregion -------------------------------------- View

    //region -------------------------------------- Actions
    function setSettings(IOS.OsSettings memory st) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        $.osSettings[0] = st;

        emit IOS.OsSettingsUpdated(st);
    }

    function createDAO(
        string calldata name,
        string calldata daoSymbol,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) internal {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();

        uint daoUid = ++$.daoCount;

        OsLib.DaoDataLocal memory daoData;
        daoData.name = name;
        daoData.symbol = daoSymbol;
        daoData.phase = ITokenomics.LifecyclePhase.DRAFT_0;
        daoData.deployer = msg.sender;
        daoData.activity = activity;

        OsLib.validate(daoData, params, funding);

        // ------------------------- Save DAO data to the storage
        // we don't use viaIR=true in config so we cannot make direct assignment
        // $.daos[daoSymbol] = daoData;

        $.daoUids[daoSymbol] = daoUid;
        $.daos[daoUid] = daoData;
        $.daoParameters[daoUid] = params;
        $.tokenomics[daoUid].initialChain = block.chainid;
        $.tokenomics[daoUid].countFunding = funding.length;

        for (uint i = 0; i < funding.length; i++) {
            $.funding[getKey(daoUid, i)] = funding[i];
        }

        $.usedSymbols[daoSymbol] = true;

        // ------------------------- Notify about a newly created DAO
        emit IOS.DaoCreated(name, daoSymbol, activity, params, funding);

        _sendCrossChainMessage(IOS.CrossChainMessages.NEW_DAO_SYMBOL_0, daoSymbol);
    }

    function addLiveDAO(ITokenomics.DaoData memory dao) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();

        uint daoUid = ++$.daoCount;

        OsLib.DaoDataLocal memory local;
        local.name = dao.name;
        local.symbol = dao.symbol;
        local.phase = dao.phase;
        local.deployer = dao.deployer;
        local.activity = dao.activity;
        local.countUnits = uint32(dao.units.length);
        local.countAgents = uint32(dao.agents.length);

        OsLib.validate(local, dao.params, dao.tokenomics.funding);
        // todo validate other fields
        // todo require block.chain == dao.tokenomics.initialChain

        // ------------------------- Save DAO data to the storage
        $.daoUids[dao.symbol] = daoUid;
        $.daos[daoUid] = local;
        $.daoImages[daoUid] = dao.images;
        $.deployments[daoUid] = dao.deployments;
        $.daoParameters[daoUid] = dao.params;

        {
            OsLib.TokenomicsLocal memory tokenomics;
            tokenomics.initialChain = dao.tokenomics.initialChain;
            tokenomics.countFunding = uint32(dao.tokenomics.funding.length);
            tokenomics.countVesting = uint32(dao.tokenomics.vesting.length);

            $.tokenomics[daoUid] = tokenomics;
        }

        {
            OsLib.BuilderActivityLocal memory baLocal;
            baLocal.multisig = dao.builderActivity.multisig;
            baLocal.repo = dao.builderActivity.repo;
            baLocal.countWorkers = uint32(dao.builderActivity.workers.length);
            baLocal.countConveyors = uint32(dao.builderActivity.conveyors.length);
            baLocal.countPools = uint32(dao.builderActivity.pools.length);
            baLocal.countBurnRate = uint32(dao.builderActivity.burnRate.length);

            $.builderActivity[daoUid] = baLocal;

            for (uint i = 0; i < baLocal.countWorkers; i++) {
                $.builderActivityWorkers[getKey(daoUid, i)] = dao.builderActivity.workers[i];
            }

            for (uint i = 0; i < baLocal.countConveyors; i++) {
                $.builderActivityConveyors[getKey(daoUid, i)] = dao.builderActivity.conveyors[i];
            }

            for (uint i = 0; i < baLocal.countPools; i++) {
                $.builderActivityPools[getKey(daoUid, i)] = dao.builderActivity.pools[i];
            }

            for (uint i = 0; i < baLocal.countBurnRate; i++) {
                $.builderActivityBurnRate[getKey(daoUid, i)] = dao.builderActivity.burnRate[i];
            }
        }
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
     function getKey(uint daoUid, uint index) internal pure returns (bytes32) {
        return keccak256(abi.encode(daoUid, index));
    }
    //endregion -------------------------------------- Internal utils


}