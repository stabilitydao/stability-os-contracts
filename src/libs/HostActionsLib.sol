// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {IHost} from "../interfaces/IHost.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {HostLib} from "./HostLib.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {HostUpdateLib} from "./HostUpdateLib.sol";

library HostActionsLib {
    using SafeERC20 for IERC20;

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
    function initOS(IHost.HostInitPayload memory initPayload) external {
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

        uint daoUid = HostLib.generateDaoUid($);

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
    function addLiveDAO(ITokenomics.DaoData memory dao) external {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        uint daoUid = HostLib.generateDaoUid($);

        HostLib.DaoDataLocal memory local;
        local.name = dao.name;
        local.symbol = dao.symbol;
        local.phase = dao.phase;
        local.deployer = dao.deployer;
        local.socials = dao.socials;
        local.activity = dao.activity;
        local.countUnits = uint32(dao.units.length);
        local.countAgents = uint32(dao.agents.length);

        HostUpdateLib.validate(local, dao.params, dao.tokenomics.funding);
        // todo validate other fields
        // todo require block.chain == dao.tokenomics.initialChain

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

        for (uint i; i < dao.units.length; i++) {
            ITokenomics.UnitInfo storage unitInfo = $.units[HostLib.getKey(daoUid, i)];
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
            $.agents[HostLib.getKey(daoUid, i)] = dao.agents[i];
        }

        // todo do we need to register exit proposals?

        _finalizeDaoCreation($, dao.symbol, dao.name, daoUid);
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
        // take DAO creation fee on balance of this contract
        address exchangeAsset = $.osChainSettings[0].exchangeAsset;
        require(exchangeAsset != address(0), IHost.IncorrectConfiguration());

        uint priceDao = $.osSettings[0].priceDao;
        if (priceDao != 0) {
            IERC20(exchangeAsset).safeTransferFrom(msg.sender, address(this), priceDao);
        }

        $.usedSymbols[daoSymbol] = true;

        emit IHost.DaoCreated(daoName, daoSymbol, daoUid);

        HostCrossChainLib.sendMessageNewSymbol(daoSymbol);
    }
    //endregion -------------------------------------- Internal logic

    //region -------------------------------------- Internal utils
    //endregion -------------------------------------- Internal utils
}
