// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics, IDAOUnit} from "../../interfaces/ITokenomics.sol";
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

            dest.tokenomics.funding = new ITokenomics.Funding[](tokenomics.funding.length);
            for (uint i; i < dest.tokenomics.funding.length; i++) {
                dest.tokenomics.funding[i] = $.funding[getKey(daoUid, i)];
            }

            dest.tokenomics.vesting = new ITokenomics.Vesting[](tokenomics.countVesting);
            for (uint i; i < tokenomics.countVesting; i++) {
                dest.tokenomics.vesting[i] = $.vesting[getKey(daoUid, i)];
            }
        }

        return dest;
    }

    function getSettings() external view returns (IOS.OsSettings memory) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        return $.osSettings[0];
    }

    /// @notice Get list of pending tasks for the given DAO
    /// @param daoSymbol DAO symbol
    /// @param limit Maximum number of tasks to return. It must be > 0. Use 1 to check if there are any tasks.
    /// @return _tasks List of tasks. The list is limited by {limit} value
    function tasks(string calldata daoSymbol, uint limit) external view returns (IOS.Task[] memory _tasks) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        _tasks = new IOS.Task[](limit);

        // slither-disable-next-line uninitialized-local
        uint index;

        uint daoUid = $.daoUids[daoSymbol];
        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;

        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            ITokenomics.DaoImages memory daoImages = $.daoImages[daoUid];
            if (index < limit && bytes(daoImages.seedToken).length == 0 || bytes(daoImages.token).length == 0) {
                _tasks[index++] = IOS.Task("Need images of token and seedToken");
            }
            if (index < limit && $.daos[daoUid].socials.length < 2) {
                _tasks[index++] = IOS.Task("Need at least 2 socials");
            }
            if (index < limit && $.daos[daoUid].countUnits == 0) {
                _tasks[index++] = IOS.Task("Need at least 1 projected unit");
            }
        } else if (phase == ITokenomics.LifecyclePhase.SEED_1) {
            ITokenomics.Funding memory f = $.funding[getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
            if (f.fundingType == ITokenomics.FundingType.SEED_0) { // todo check if funding round exists. Can SEED_0 be skipped? if yes we need differen way to check if it exists
                if (index < limit && f.raised < f.minRaise && f.end > block.timestamp) {
                    _tasks[index++] = IOS.Task("Need attract minimal seed funding");
                }
            }
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            ITokenomics.Funding memory f = $.funding[getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
            if (index < limit && f.fundingType != ITokenomics.FundingType.TGE_1) {
                _tasks[index++] = IOS.Task("Need add pre-TGE funding");
            }
            ITokenomics.DaoImages memory daoImages = $.daoImages[daoUid];
            if (index < limit && bytes(daoImages.tgeToken).length == 0 || bytes(daoImages.xToken).length == 0 || bytes(daoImages.daoToken).length == 0) {
                _tasks[index++] = IOS.Task("Need images of all DAO tokens");
            }
            if (index < limit && $.tokenomics[daoUid].countVesting == 0) {
                _tasks[index++] = IOS.Task("Need vesting allocations");
            }
            uint countUnits = $.daos[daoUid].countUnits;

            // slither-disable-next-line uninitialized-local
            bool foundLive;

            for (uint i; i < countUnits; i++) {
                ITokenomics.UnitInfo memory unit = $.units[getKey(daoUid, i)];
                if (unit.status == IDAOUnit.UnitStatus.LIVE_2) {
                    foundLive = true;
                    break;
                }
            }
            if (index < limit && !foundLive) {
                _tasks[index++] = IOS.Task("Run revenue generating units");
            }

        } else if (phase == ITokenomics.LifecyclePhase.TGE_4) {

        } else if (phase == ITokenomics.LifecyclePhase.LIVE_CLIFF_5) {

        } else if (phase == ITokenomics.LifecyclePhase.LIVE_VESTING_6) {

        } else if (phase == ITokenomics.LifecyclePhase.LIVE_7) {

        }

        return _tasks;
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

        for (uint i = 0; i < funding.length; i++) {
            $.tokenomics[daoUid].funding.push(funding[i].fundingType);
            $.funding[getKey(daoUid, i)] = funding[i];
        }

        _finalizeDaoCreation($, daoSymbol, name, daoUid);
    }

    function addLiveDAO(ITokenomics.DaoData memory dao) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();

        uint daoUid = ++$.daoCount;

        OsLib.DaoDataLocal memory local;
        local.name = dao.name;
        local.symbol = dao.symbol;
        local.phase = dao.phase;
        local.deployer = dao.deployer;
        local.socials = dao.socials;
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

        { // ------------------------- tokenomics
            OsLib.TokenomicsLocal memory tokenomics;
            tokenomics.initialChain = dao.tokenomics.initialChain;
            tokenomics.countVesting = uint32(dao.tokenomics.vesting.length);

            $.tokenomics[daoUid] = tokenomics;

            for (uint i; i < dao.tokenomics.funding.length; i++) {
                $.tokenomics[daoUid].funding.push(dao.tokenomics.funding[i].fundingType);
                $.funding[getKey(daoUid, i)] = dao.tokenomics.funding[i];
            }
            for (uint i; i < dao.tokenomics.vesting.length; i++) {
                $.vesting[getKey(daoUid, i)] = dao.tokenomics.vesting[i];
            }
        }

        for (uint i; i < dao.units.length; i++) {
            ITokenomics.UnitInfo storage unitInfo = $.units[getKey(daoUid, i)];
            unitInfo.unitId = dao.units[i].unitId;
            unitInfo.name = dao.units[i].name;
            unitInfo.status = dao.units[i].status;
            unitInfo.unitType = dao.units[i].unitType;
            unitInfo.revenueShare = dao.units[i].revenueShare;
            unitInfo.emoji = dao.units[i].emoji;
            unitInfo.api = dao.units[i].api;
            for (uint j; j < dao.units[i].ui.length; ++j) {
                unitInfo.ui.push(dao.units[i].ui[j]);
            }
        }
        for (uint i; i < dao.agents.length; i++) {
            $.agents[getKey(daoUid, i)] = dao.agents[i];
        }

        // todo do we need to register exit proposals?

        _finalizeDaoCreation($, dao.symbol, dao.name, daoUid);
    }

    /// @notice Change lifecycle phase of a DAO
    function changePhase(string calldata daoSymbol) external {
        // todo
    }

    function fund(string calldata daoSymbol, uint256 amount) external {
        // todo
    }

    function receiveVotingResults(string calldata proposalId, bool succeed) external {
        // todo
    }
    //endregion -------------------------------------- Actions


    //region -------------------------------------- Internal logic

    /// @notice Mark DAO symbol as used and emit events
    function _finalizeDaoCreation(OsLib.OsStorage storage $, string memory daoSymbol, string memory daoName, uint daoUid) internal {
        $.usedSymbols[daoSymbol] = true;

        emit IOS.DaoCreated(daoName, daoSymbol, daoUid);

        _sendCrossChainMessage(IOS.CrossChainMessages.NEW_DAO_SYMBOL_0, daoSymbol);
    }

    /// @notice Send cross-chain message about DAO event
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