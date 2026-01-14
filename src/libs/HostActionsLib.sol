// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {IHost} from "../interfaces/IHost.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {HostLib} from "./HostLib.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {HostUpdateLib} from "./HostUpdateLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library HostActionsLib {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    //region -------------------------------------- Restricted actions
    function setSettings(IHost.HostSettings memory st) external {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        $.osSettings[0] = st;

        emit IHost.OsSettingsUpdated(st);
    }

    function setChainSettings(IHost.HostChainSettings memory st) external {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        $.osChainSettings[0] = st;

        emit IHost.OsChainSettingsUpdated(st);
    }

    /// @notice Initialize OS with existing DAO symbols from other chains
    function initHost(IHost.HostInitPayload memory initPayload) external {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        for (uint i = 0; i < initPayload.usedSymbols.length; i++) {
            string memory daoSymbol = initPayload.usedSymbols[i];
            $.usedSymbols[daoSymbol] = true;
        }
    }

    //endregion -------------------------------------- Restricted actions

    //region -------------------------------------- Actions

    /// @notice Create new DAO
    /// @param name Name of new DAO (any name is allowed)
    /// @param daoSymbol Symbol of new DAO (should be unique across all DAOs, it can be changed later)
    /// @param activity List of activities of the DAO
    /// @param params On-chain DAO parameters
    /// @param funding Initial funding rounds of the DAO
    function createDAO(
        string calldata name,
        string calldata daoSymbol,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) external {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        // todo currently host dao is set by first created dao, is it safe?
        (uint daoUid, bool firstDao) = HostLib.generateDaoUid($);
        if (firstDao) {
            $.hostDaoUid = daoUid;
        }

        HostLib.DaoDataLocal memory daoData;
        daoData.name = name;
        daoData.symbol = daoSymbol;
        daoData.phase = ITokenomics.LifecyclePhase.DRAFT_0;
        daoData.deployer = msg.sender;
        daoData.activity = activity;

        HostUpdateLib.validate(daoData, params, funding);

        // ------------------------- Save DAO data to the storage
        // we don't use viaIR=true in config so we cannot make direct assignment
        // $.daos[daoSymbol] = daoData;

        $.daoUids[daoSymbol] = daoUid;
        $.daos[daoUid] = daoData;
        $.daoParameters[daoUid] = params;
        $.tokenomics[daoUid].initialChain = block.chainid;

        for (uint i = 0; i < funding.length; i++) {
            $.tokenomics[daoUid].funding.push(funding[i].fundingType);
            $.funding[HostLib.getKey(daoUid, i)] = funding[i];
        }

        _finalizeDaoCreation($, daoSymbol, name, daoUid);
    }

    /// @notice Add live DAO verified off-chain into the system
    function addLiveDAO(ITokenomics.DaoMetaData memory dao) external {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        (uint daoUid,) = HostLib.generateDaoUid($);

        HostLib.DaoDataLocal memory local;
        local.name = dao.name;
        local.symbol = dao.symbol;
        local.phase = dao.phase;
        local.deployer = dao.deployer;
        local.socials = dao.socials;
        local.activity = dao.activity;
        local.countAgents = uint32(dao.agents.length);
        local.hashUnitIds = new bytes32[](dao.units.length);

        HostUpdateLib.validate(local, dao.params, dao.tokenomics.funding);
        // todo validate other fields
        // todo require block.chain == dao.tokenomics.initialChain

        // ------------------------- Prepare units data
        for (uint i; i < dao.units.length; i++) {
            local.hashUnitIds[i] = HostLib.getKey(daoUid, dao.units[i].chainData.unitId);
            require($.units[local.hashUnitIds[i]].daoUid == 0, IHost.UnitAlreadyRegistered());

            HostLib.UnitLocal storage unit = $.units[local.hashUnitIds[i]];
            unit.daoUid = daoUid;
            unit.data = dao.units[i].chainData;
            unit.chainIds.add(block.chainid);

            emit IHost.DaoUnitUpdated(daoUid, dao.units[i].metaData);
        }

        // ------------------------- Save DAO data to the storage
        $.daoUids[dao.symbol] = daoUid;
        $.daos[daoUid] = local;
        $.daoImages[daoUid] = dao.images;
        $.deployments[daoUid] = dao.deployments;
        $.daoParameters[daoUid] = dao.params;

        { // ------------------------- tokenomics
            HostLib.TokenomicsLocal memory tokenomics;
            tokenomics.initialChain = dao.tokenomics.initialChain;
            tokenomics.countVesting = uint32(dao.tokenomics.vesting.length);

            $.tokenomics[daoUid] = tokenomics;

            for (uint i; i < dao.tokenomics.funding.length; i++) {
                $.tokenomics[daoUid].funding.push(dao.tokenomics.funding[i].fundingType);
                $.funding[HostLib.getKey(daoUid, i)] = dao.tokenomics.funding[i];
            }
            for (uint i; i < dao.tokenomics.vesting.length; i++) {
                $.vesting[HostLib.getKey(daoUid, i)] = dao.tokenomics.vesting[i];
            }
        }

        for (uint i; i < dao.agents.length; i++) {
            $.agents[HostLib.getKey(daoUid, i)] = dao.agents[i];
        }

        _finalizeDaoCreation($, dao.symbol, dao.name, daoUid);
    }

    /// @notice Process revenue for the given unit of the DAO
    function processUnitRevenue(string calldata daoSymbol, string memory unitId, uint amount) external {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];

        require(daoUid != 0, IHost.IncorrectDao());
        require(_isUnitExist($, daoUid, unitId), IHost.UnitNotFound());

        HostActionsLib._processUnitRevenue($, daoUid, daoSymbol, unitId, amount);
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Internal logic
    /// @notice Mark DAO symbol as used and emit events
    function _finalizeDaoCreation(
        HostLib.OsStorage storage $,
        string memory daoSymbol,
        string memory daoName,
        uint daoUid
    ) internal {
        uint hostDaoUid = $.hostDaoUid;
        // assume here that hostDaoUid cannot be 0 because $.hostDaoUid is initializing before paying creation fee

        // todo probably host-dao shouldn't pay creation fee to itself, so we need to check: if (hostDaoUid != daoUid) {

        // we don't check if HOST_UNIT exists in host-dao because it's (only) virtual unit

        // DAO creation fee is put to host-unit of the host-dao
        _processUnitRevenue(
            $,
            hostDaoUid,
            "", // todo symbol of host dao, can we keep it empty here?
            HostLib.HOST_UNIT,
            $.osSettings[0].priceDao
        );

        $.usedSymbols[daoSymbol] = true;

        emit IHost.DaoCreated(daoName, daoSymbol, daoUid);

        HostCrossChainLib.sendMessageNewSymbol(daoSymbol);
    }

    /// @notice Check if the given dao has a unit with the given {unitId}
    function _isUnitExist(HostLib.OsStorage storage $, uint daoUid, string memory unitId) internal view returns (bool) {
        return $.units[HostLib.getKey(daoUid, unitId)].daoUid != 0;
    }

    /// @notice Take revenue from the given user on balance of the Host. Register revenue to the given unit.
    function _processUnitRevenue(
        HostLib.OsStorage storage $,
        uint daoUid,
        string memory daoSymbol,
        string memory unitId,
        uint amount
    ) internal {
        if (amount != 0) {
            address exchangeAsset = $.osChainSettings[0].exchangeAsset;
            require(exchangeAsset != address(0), IHost.IncorrectConfiguration());

            // currently assume that all revenues should be put on the Host balance
            IERC20(exchangeAsset).safeTransferFrom(msg.sender, address(this), amount);
            $.unitBalances[HostLib.getKey(daoUid, unitId)] += amount;

            emit IHost.ProcessUnitRevenue(daoUid, daoSymbol, unitId, amount);
        }
    }
    //endregion -------------------------------------- Internal logic

    //region -------------------------------------- Internal utils
    //endregion -------------------------------------- Internal utils
}
