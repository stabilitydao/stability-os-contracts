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
import {HostProxyLib} from "./HostProxyLib.sol";
import {HostEncodingLib} from "./HostEncodingLib.sol";
import {HostDeployLib} from "./HostDeployLib.sol";
import {HostViewLib} from "./HostViewLib.sol";

library HostActionsLib {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    //region -------------------------------------- Initialization

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
                string memory symbol = initPayload.usedSymbols[i];
                $.daoUids[symbol] = daoUidStub;
            }
        }

        // ------------------------- Set up host DAO if any
        if (initPayload.daoHostUid != 0) {
            $.daoUids[initPayload.daoHostSymbol] = initPayload.daoHostUid;
            $.hostDaoUid = initPayload.daoHostUid;
        }

        HostProxyLib.initialize(initPayload.hostVersion);
        emit IHost.HostInitialized(
            initPayload.daoHostSymbol, initPayload.daoHostUid, initPayload.hostVersion, initPayload.usedSymbols
        );
    }

    //endregion -------------------------------------- Initialization

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

    //endregion -------------------------------------- Restricted actions

    //region -------------------------------------- Actions

    /// @notice Create new DAO
    /// @param name Name of new DAO (any name is allowed)
    /// @param symbol Symbol of new DAO (should be unique across all DAOs, it can be changed later)
    /// @param activity List of activities of the DAO
    /// @param params On-chain DAO parameters
    /// @param funding Initial funding rounds of the DAO
    function createDAO(
        string calldata name,
        string calldata symbol,
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
        daoData2.symbol = symbol;
        daoData2.phase = ITokenomics.LifecyclePhase.DRAFT_0;

        HostUpdateLib.validate(daoUid, ITokenomics.LifecyclePhase.DRAFT_0, daoData2, params, funding, activity);

        // ------------------------- Save DAO data to the storage
        $.segment2[daoUid] = daoData2;
        $.daoParameters[daoUid] = params;

        {
            HostLib.DaoDataSegment3 storage segment3 = $.segment3[daoUid];
            segment3.initialChain = block.chainid;
            segment3.deployer = msg.sender;
            segment3.activity = activity;

            for (uint i = 0; i < funding.length; i++) {
                segment3.funding.push(funding[i].fundingType);
                $.funding[HostLib.getKey(daoUid, uint(funding[i].fundingType))] = funding[i];
            }
        }

        _finalizeDaoCreation($, symbol, name, daoUid);
    }

    /// @notice Process revenue for the given unit of the DAO
    function processUnitRevenue(string calldata symbol, string memory unitId, uint amount) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);

        require(daoUid != 0, IHost.IncorrectDao());
        require(_isUnitExist($, daoUid, unitId), IHost.UnitNotFound());

        HostActionsLib._processUnitRevenue($, daoUid, symbol, unitId, amount);
    }

    /// @notice Change lifecycle phase of a DAO
    /// @param symbol Symbol of the DAO
    function changePhase(string calldata symbol, address authority) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);

        require(daoUid != 0, IHost.IncorrectDao());
        require(HostViewLib._tasks(1, daoUid).length == 0, IHost.SolveTasksFirst());

        ITokenomics.LifecyclePhase phase = $.segment2[daoUid].phase;
        ITokenomics.LifecyclePhase newPhase = phase;

        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
            require(seed.start < block.timestamp, IHost.WaitFundingStart());

            // todo Inception phase
            //            // SEED can be started not later than 1 week after configured start time
            //            require(
            //                block.timestamp <= seed.start + HostConfigLib.getHostGlobalSettings().maxSeedStartDelay,
            //                IHost.TooLateSoSetupFundingAgain()
            //            );

            $.deployments[daoUid].seedToken = HostDeployLib.deploySeedToken($, daoUid, authority);

            newPhase = ITokenomics.LifecyclePhase.SEED_1;
        } else if (phase == ITokenomics.LifecyclePhase.SEED_1) {
            ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
            require(seed.end <= block.timestamp, IHost.WaitFundingEnd());

            bool success = seed.raised >= seed.minRaise;

            if (success) {
                newPhase = ITokenomics.LifecyclePhase.DEVELOPMENT_3;
            } else {
                newPhase = ITokenomics.LifecyclePhase.SEED_FAILED_2;
                // now refund can be called
            }
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            ITokenomics.Funding memory tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

            require(tge.start <= block.timestamp, IHost.WaitFundingStart());

            $.deployments[daoUid].tgeToken = HostDeployLib.deployTgeToken($, daoUid, authority);

            newPhase = ITokenomics.LifecyclePhase.TGE_4;
        } else if (phase == ITokenomics.LifecyclePhase.TGE_4) {
            ITokenomics.Funding memory tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

            require(tge.end < block.timestamp, IHost.WaitFundingEnd());

            bool success = tge.raised >= tge.minRaise;

            if (success) {
                // todo deploy token, xToken, staking, daoToken

                $.deployments[daoUid].token = address(0); // todo deployed token
                $.deployments[daoUid].xToken = address(0); // todo deployed xToken
                $.deployments[daoUid].staking = address(0); // todo deployed staking token
                $.deployments[daoUid].daoToken = address(0); // todo deployed daoToken

                // todo deploy vesting contracts and allocate token

                // todo seedToken holders became xToken holders by predefined rate

                // todo deploy v2 liquidity from TGE funds at predefined price
                newPhase = ITokenomics.LifecyclePhase.LIVE_CLIFF_5;
            } else {
                newPhase = ITokenomics.LifecyclePhase.DEVELOPMENT_3;
                // now refund can be called
                // refunding is available up to the start of next TGE
            }
        } else if (phase == ITokenomics.LifecyclePhase.LIVE_CLIFF_5) {
            // if any vesting started then phase changed

            // slither-disable-next-line uninitialized-local
            bool isVestingStarted;

            uint countVesting = $.segment3[daoUid].countVesting;
            for (uint i; i < countVesting; i++) {
                if ($.vesting[HostLib.getKey(daoUid, i)].start < block.timestamp) {
                    isVestingStarted = true;
                    break;
                }
            }

            require(isVestingStarted, IHost.WaitVestingStart());

            newPhase = ITokenomics.LifecyclePhase.LIVE_VESTING_6;
        } else if (phase == ITokenomics.LifecyclePhase.LIVE_VESTING_6) {
            // slither-disable-next-line uninitialized-local
            bool isVestingActive;

            uint countVesting = $.segment3[daoUid].countVesting;
            for (uint i; i < countVesting; i++) {
                if ($.vesting[HostLib.getKey(daoUid, i)].end > block.timestamp) {
                    isVestingActive = true;
                    break;
                }
            }

            require(!isVestingActive, IHost.WaitVestingEnd());

            newPhase = ITokenomics.LifecyclePhase.LIVE_7;
        }

        $.segment2[daoUid].phase = newPhase;

        emit IHost.DaoPhaseChanged(daoUid, newPhase);
    }

    /// @dev Add exist DAO to Host
    function updateByAdmin(IHost.AdminUpdateActions actionIndex, bytes memory payload) external {
        if (actionIndex == IHost.AdminUpdateActions.ADD_LIVE_DAO_0) {
            IDAOData.DaoDataInput memory dao = HostEncodingLib.decodeDaoDataInput(payload);
            _addLiveDAO(dao);
        } else {
            revert IHost.UnknownRestrictedAction();
        }
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Internal logic
    /// @notice Mark DAO symbol as used and emit events
    function _finalizeDaoCreation(
        HostLib.HostStorage storage $,
        string memory symbol,
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
            $.segment2[hostDaoUid].symbol,
            HostLib.HOST_UNIT,
            HostConfigLib.getHostGlobalSettings().priceDao
        );

        $.daoUids[symbol] = daoUid;

        emit IHost.DaoCreated(daoName, symbol, daoUid);

        HostCrossChainLib.sendMessageToAllChains(
            IHost.CrossChainMessages.NEW_DAO_SYMBOL_0, HostCrossChainLib.packMessageNewDaoSymbol(symbol)
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
        string memory symbol,
        string memory unitId,
        uint amount
    ) internal {
        if (amount != 0) {
            address exchangeAsset = HostConfigLib.getHostChainSettings().exchangeAsset;
            require(exchangeAsset != address(0), IHost.IncorrectConfiguration());

            // currently assume that all revenues should be put on the Host balance
            IERC20(exchangeAsset).safeTransferFrom(msg.sender, address(this), amount);
            $.unitBalances[HostLib.getUnitKey(daoUid, unitId)] += amount;

            emit IHost.ProcessUnitRevenue(daoUid, symbol, unitId, amount);
        }
    }

    /// @notice Add live DAO verified off-chain into the system
    function _addLiveDAO(IDAOData.DaoDataInput memory dao) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        (uint daoUid,) = HostLib.generateDaoUid($);

        // ------------------------- Segment 2

        HostLib.DaoDataSegment2 memory daoData2;
        daoData2.name = dao.name;
        daoData2.symbol = dao.symbol;
        daoData2.phase = dao.phase;
        daoData2.unitIds = new string[](dao.units.length);

        HostUpdateLib.validate(daoUid, dao.phase, daoData2, dao.params, dao.funding, dao.activity);

        // ------------------------- Prepare units data
        require(dao.units.length == dao.unitsMetaData.length, IHost.IncorrectArrayLengths());

        for (uint i; i < dao.units.length; i++) {
            bytes32 hashUnitId = HostLib.getUnitKey(daoUid, dao.units[i].unitId);
            HostLib.UnitLocal storage unit = $.units[hashUnitId];

            daoData2.unitIds[i] = dao.units[i].unitId;
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
                $.funding[HostLib.getKey(daoUid, uint(dao.funding[i].fundingType))] = dao.funding[i];
            }
        }

        { // ------------------------- vesting
            uint countVesting = uint32(dao.vesting.length);
            segment3.countVesting = countVesting;

            for (uint i; i < dao.vesting.length; i++) {
                $.vesting[HostLib.getIndexKey(daoUid, i)] = HostLib.VestingLocal({
                    name: dao.vesting[i].name,
                    allocation: dao.vesting[i].allocation,
                    start: dao.vesting[i].start,
                    end: dao.vesting[i].end
                });
                emit IHost.VestingDescription(daoUid, dao.vesting[i].name, dao.vesting[i].description);
            }
        }

        _finalizeDaoCreation($, dao.symbol, dao.name, daoUid);
    }

    //endregion -------------------------------------- Internal logic

    //region -------------------------------------- Internal utils
    //endregion -------------------------------------- Internal utils
}
