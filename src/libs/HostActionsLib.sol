// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {IHost} from "../interfaces/IHost.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {HostLib} from "./HostLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {HostUpdateLib} from "./HostUpdateLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library HostActionsLib {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    //region -------------------------------------- Restricted actions
    function setSettings(IHost.HostSettings memory st) external {
        HostConfigLib.HostGlobalStorage storage $ = HostConfigLib.getHostGlobalStorage();
        $.globalSettings = st;

        emit IHost.OsSettingsUpdated(st);
    }

    function setChainSettings(IHost.HostChainSettings memory st) external {
        HostConfigLib.HostChainStorage storage $ = HostConfigLib.getHostChainStorage();
        $.chainSettings = st;

        emit IHost.OsChainSettingsUpdated(st);
    }

    /// @notice Initialize OS with existing DAO symbols from other chains
    function initHost(IHost.HostInitPayload memory initPayload) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        // ------------------------- Setup DAO counter
        HostLib.setupDaoCounter();

        // ------------------------- Register all used symbols
        uint len = initPayload.usedSymbols.length;
        if (len != 0) {
            uint daoUidStub = HostLib.getDaoUidStub();
            for (uint i = 0; i < len; i++) {
                string memory daoSymbol = initPayload.usedSymbols[i];
                $.daoUids[daoSymbol] = daoUidStub;
            }
        }

        // ------------------------- Set up host DAO if any
        if (initPayload.daoHostUid != 0) {
            $.daoUids[initPayload.daoHostSymbol] = initPayload.daoHostUid;
            $.hostDaoUid = initPayload.daoHostUid;
        }

        // todo event Host initialized
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
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        // todo currently host dao is set by first created dao, is it safe?
        (uint daoUid, bool firstDao) = HostLib.generateDaoUid($);
        if (firstDao) {
            $.hostDaoUid = daoUid;
        }

        HostLib.DaoDataSegment2 memory daoData2;
        daoData2.name = name;
        daoData2.daoSymbol = daoSymbol;
        daoData2.phase = ITokenomics.LifecyclePhase.DRAFT_0;

        HostUpdateLib.validate(daoData2, params, funding);

        // ------------------------- Save DAO data to the storage
        // we don't use viaIR=true in config so we cannot make direct assignment
        // $.daos[daoSymbol] = daoData;

        $.segment2[daoUid] = daoData2;
        $.daoParameters[daoUid] = params;

        {
            HostLib.DaoDataSegment3 storage segment3 = $.segment3[daoUid];
            segment3.initialChain = block.chainid;
            segment3.deployer = msg.sender;
            segment3.activity = activity;

            for (uint i = 0; i < funding.length; i++) {
                segment3.funding.push(funding[i].fundingType);
                $.funding[HostLib.getIndexKey(daoUid, i)] = funding[i];
            }
        }

        _finalizeDaoCreation($, daoSymbol, name, daoUid);
    }

    /// @notice Add live DAO verified off-chain into the system
    function addLiveDAO(IDAOData.DaoDataInput calldata dao) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        (uint daoUid,) = HostLib.generateDaoUid($);

        // ------------------------- Segment 2

        HostLib.DaoDataSegment2 memory daoData2;
        daoData2.name = dao.name;
        daoData2.daoSymbol = dao.symbol;
        daoData2.phase = dao.phase;
        daoData2.hashUnitIds = new bytes32[](dao.units.length);

        HostUpdateLib.validate(daoData2, dao.params, dao.funding);

        // ------------------------- Prepare units data
        require(dao.units.length == dao.unitsMetaData.length, IHost.IncorrectArrayLengths());

        for (uint i; i < dao.units.length; i++) {
            bytes32 hashUnitId = HostLib.getUnitKey(daoUid, dao.units[i].unitId);
            HostLib.UnitLocal storage unit = $.units[hashUnitId];

            daoData2.hashUnitIds[i] = hashUnitId;
            require(unit.daoUid == 0, IHost.UnitAlreadyRegistered());

            unit.daoUid = daoUid;
            unit.unitId = dao.units[i].unitId;
            unit.developerUid = dao.units[i].developerUid;
            unit.chainIds.add(block.chainid);

            emit IHost.DaoUnitUpdatedInstantly(daoUid, dao.units[i].unitId, dao.unitsMetaData[i]);
        }

        $.segment2[daoUid] = daoData2;

        // ------------------------- Segment 3
        HostLib.DaoDataSegment3 storage segment3 = $.segment3[daoUid];
        segment3.initialChain = block.chainid; // TODO: how to add exist bridged DAO?
        segment3.deployer = dao.deployer;
        segment3.activity = dao.activity;
        { // segment3.socials = dao.socials;
            uint len = dao.socials.length;
            for (uint i; i < len; i++) {
                segment3.socials.push(dao.socials[i]);
            }
        }

        // todo validate other fields

        $.daoImages[daoUid] = dao.images;
        $.deployments[daoUid] = dao.deployments;
        $.daoParameters[daoUid] = dao.params;

        { // ------------------------- funding
            for (uint i; i < dao.funding.length; i++) {
                segment3.funding.push(dao.funding[i].fundingType);
                $.funding[HostLib.getIndexKey(daoUid, i)] = dao.funding[i];
            }
        }

        { // ------------------------- vesting
            uint countVesting = uint32(dao.vesting.length);
            segment3.countVesting = countVesting;

            for (uint i; i < dao.vesting.length; i++) {
                $.vesting[HostLib.getIndexKey(daoUid, i)] = dao.vesting[i];
            }
        }

        _finalizeDaoCreation($, dao.symbol, dao.name, daoUid);
    }

    /// @notice Process revenue for the given unit of the DAO
    function processUnitRevenue(string calldata daoSymbol, string memory unitId, uint amount) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, daoSymbol);

        require(daoUid != 0, IHost.IncorrectDao());
        require(_isUnitExist($, daoUid, unitId), IHost.UnitNotFound());

        HostActionsLib._processUnitRevenue($, daoUid, daoSymbol, unitId, amount);
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Internal logic
    /// @notice Mark DAO symbol as used and emit events
    function _finalizeDaoCreation(
        HostLib.HostStorage storage $,
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
            HostConfigLib.getHostGlobalSettings().priceDao
        );

        $.daoUids[daoSymbol] = daoUid;

        emit IHost.DaoCreated(daoName, daoSymbol, daoUid);

        HostCrossChainLib.sendMessageToAllChains(
            IHost.CrossChainMessages.NEW_DAO_SYMBOL_0, HostCrossChainLib.packMessageNewDaoSymbol(daoSymbol)
        );
    }

    /// @notice Check if the given dao has a unit with the given {unitId}
    function _isUnitExist(
        HostLib.HostStorage storage $,
        uint daoUid,
        string memory unitId
    ) internal view returns (bool) {
        return $.units[HostLib.getUnitKey(daoUid, unitId)].daoUid != 0;
    }

    /// @notice Take revenue from the given user on balance of the Host. Register revenue to the given unit.
    function _processUnitRevenue(
        HostLib.HostStorage storage $,
        uint daoUid,
        string memory daoSymbol,
        string memory unitId,
        uint amount
    ) internal {
        if (amount != 0) {
            address exchangeAsset = HostConfigLib.getHostChainSettings().exchangeAsset;
            require(exchangeAsset != address(0), IHost.IncorrectConfiguration());

            // currently assume that all revenues should be put on the Host balance
            IERC20(exchangeAsset).safeTransferFrom(msg.sender, address(this), amount);
            $.unitBalances[HostLib.getUnitKey(daoUid, unitId)] += amount;

            emit IHost.ProcessUnitRevenue(daoUid, daoSymbol, unitId, amount);
        }
    }
    //endregion -------------------------------------- Internal logic

    //region -------------------------------------- Internal utils
    //endregion -------------------------------------- Internal utils
}
