// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {HostLib} from "./HostLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {HostUpdateLib} from "./HostUpdateLib.sol";
import {HostProxyLib} from "./HostProxyLib.sol";
import {HostDeployLib} from "./HostDeployLib.sol";
import {HostViewLib} from "./HostViewLib.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";

library HostActionsLib {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

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
            for (uint i; i < len; i++) {
                string memory symbol = initPayload.usedSymbols[i];
                $.daoUids[symbol] = daoUidStub;
            }
        }

        // ------------------------- Set up host DAO if any
        if (initPayload.daoHost.uid != 0) {
            $.daoUids[initPayload.daoHost.symbol] = initPayload.daoHost.uid;
            $.hostDaoUid = initPayload.daoHost.uid;
            $.segment2[initPayload.daoHost.uid] = HostLib.DaoDataSegment2({
                name: initPayload.daoHost.name,
                symbol: initPayload.daoHost.symbol,
                phase: IDAOData.LifecyclePhase.DRAFT_0,
                unitIds: initPayload.daoHost.unitIds
            });
        }

        HostProxyLib.initialize(initPayload.hostVersion);
        emit IHost.HostInitialized(initPayload.hostVersion, initPayload.usedSymbols, initPayload.daoHost);
    }

    //endregion -------------------------------------- Initialization

    //region -------------------------------------- Restricted actions
    function setSettings(IHost.HostSettings memory st) external {
        HostConfigLib.HostGlobalStorage storage $ = HostConfigLib.getHostGlobalStorage();
        $.globalSettings = st;

        emit IHost.HostSettingsUpdated(st);
    }

    function setChainSettings(IHost.HostChainSettings memory st) external {
        HostConfigLib.HostChainStorage storage $ = HostConfigLib.getHostChainStorage();
        $.chainSettings = st;

        emit IHost.HostChainSettingsUpdated(st);
    }

    /// @notice Whitelist asset for revenue processing
    /// @custom:restricted Restricted through access manager (only admin)
    /// @param assets_ Address of the assets to add to/remove from whitelist
    /// @param whitelisted True to whitelist, false to remove from whitelist
    function whitelistAsset(address[] memory assets_, bool whitelisted) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        for (uint i; i < assets_.length; i++) {
            $.whitelistedAssets[assets_[i]] = whitelisted;
        }

        emit IHost.WhitelistAsset(assets_, whitelisted);
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
        IDAOData.Activity[] memory activity,
        IDAOData.DaoParameters memory params,
        IDAOData.Funding[] memory funding
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
        daoData2.phase = IDAOData.LifecyclePhase.DRAFT_0;

        HostUpdateLib.validate(daoUid, IDAOData.LifecyclePhase.DRAFT_0, daoData2, params, funding, activity);

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
    function processUnitRevenue(string calldata symbol, string memory unitId, address asset, uint amount) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);

        require(daoUid != 0, IHost.IncorrectDao());
        /// @dev Zero amount are not allowed to be able to check if any revenue registered by reading length of registered assets
        require(amount != 0, IHosted.ZeroAmount());
        require(_isUnitExist($, daoUid, unitId), IHost.UnitNotFound());
        require($.whitelistedAssets[asset], IHost.AssetNotWhitelisted());

        HostActionsLib._processUnitRevenue($, daoUid, symbol, unitId, asset, amount);
    }

    /// @notice Change lifecycle phase of a DAO
    /// @param symbol Symbol of the DAO
    function changePhase(string calldata symbol, address authority) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);

        require(daoUid != 0, IHost.IncorrectDao());
        require(HostViewLib._tasks(1, daoUid).length == 0, IHost.SolveTasksFirst());

        IDAOData.LifecyclePhase phase = $.segment2[daoUid].phase;
        IDAOData.LifecyclePhase newPhase = phase;

        if (phase == IDAOData.LifecyclePhase.DRAFT_0) {
            newPhase = _changePhaseDraft($, daoUid);
        } else if (phase == IDAOData.LifecyclePhase.INCEPTION_1) {
            newPhase = _changePhaseInception($, daoUid, authority);
        } else if (phase == IDAOData.LifecyclePhase.SEED_2) {
            newPhase = _changePhaseSeed($, daoUid);
        } else if (phase == IDAOData.LifecyclePhase.DEVELOPMENT_4) {
            newPhase = _changePhaseDevelopment($, daoUid, authority);
        } else if (phase == IDAOData.LifecyclePhase.TGE_5) {
            newPhase = _changePhaseTge($, daoUid, authority);
        } else if (phase == IDAOData.LifecyclePhase.LIVE_CLIFF_6) {
            newPhase = _changePhaseLiveCliff($, daoUid);
        } else if (phase == IDAOData.LifecyclePhase.LIVE_VESTING_7) {
            newPhase = _changePhaseLiveVesting($, daoUid);
        }

        $.segment2[daoUid].phase = newPhase;

        emit IHost.DaoPhaseChanged(daoUid, newPhase);
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
        uint amount = HostConfigLib.getHostGlobalSettings().priceDao;
        if (amount != 0) {
            address exchangeAsset = HostConfigLib.getHostChainSettings().exchangeAsset;
            // we don't check if exchange asset is whitelisted, assume it's configured correctly
            require(exchangeAsset != address(0), IHost.IncorrectConfiguration());

            _processUnitRevenue(
                $,
                hostDaoUid,
                $.segment2[hostDaoUid].symbol,
                HostLib.HOST_UNIT,
                exchangeAsset,
                HostConfigLib.getHostGlobalSettings().priceDao
            );
        }

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
        address asset,
        uint amount
    ) internal {
        // currently assume that all revenues should be put on the Host balance
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        EnumerableMap.AddressToUintMap storage values = $.unitBalances[HostLib.getUnitKey(daoUid, unitId)];
        (, uint currentBalance) = values.tryGet(asset);

        values.set(asset, currentBalance + amount);

        emit IHost.ProcessUnitRevenue(daoUid, symbol, unitId, amount);
    }

    //endregion -------------------------------------- Internal logic

    //region -------------------------------------- Change phase utils
    function _changePhaseDraft(
        HostLib.HostStorage storage $,
        uint daoUid
    ) internal view returns (IDAOData.LifecyclePhase phase) {
        IDAOData.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.SEED_0))];
        // SEED can be started not later than 1 week after configured start time
        require(
            block.timestamp + HostConfigLib.getHostGlobalSettings().minInceptionDuration <= seed.start,
            IHost.TooLateSoSetupFundingAgain()
        );
        return IDAOData.LifecyclePhase.INCEPTION_1;
    }

    function _changePhaseInception(
        HostLib.HostStorage storage $,
        uint daoUid,
        address authority
    ) internal returns (IDAOData.LifecyclePhase phase) {
        IDAOData.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.SEED_0))];
        require(seed.start < block.timestamp, IHost.WaitFundingStart());

        $.deployments[daoUid].seedToken = HostDeployLib.deploySeedToken($, daoUid, authority);

        return IDAOData.LifecyclePhase.SEED_2;
    }

    function _changePhaseSeed(
        HostLib.HostStorage storage $,
        uint daoUid
    ) internal view returns (IDAOData.LifecyclePhase) {
        IDAOData.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.SEED_0))];
        require(seed.end <= block.timestamp, IHost.WaitFundingEnd());

        bool success = seed.raised >= seed.minRaise;

        // todo Take fee from successful seeding, see HostSettings.fundingFee

        return success ? IDAOData.LifecyclePhase.DEVELOPMENT_4 : IDAOData.LifecyclePhase.SEED_FAILED_3; // now refund can be called
    }

    function _changePhaseDevelopment(
        HostLib.HostStorage storage $,
        uint daoUid,
        address authority
    ) internal returns (IDAOData.LifecyclePhase) {
        IDAOData.Funding memory tge = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.TGE_1))];

        require(tge.start <= block.timestamp, IHost.WaitFundingStart());

        $.deployments[daoUid].tgeToken = HostDeployLib.deployTgeToken($, daoUid, authority);

        return IDAOData.LifecyclePhase.TGE_5;
    }

    function _changePhaseTge(
        HostLib.HostStorage storage $,
        uint daoUid,
        address authority
    ) internal returns (IDAOData.LifecyclePhase) {
        IDAOData.Funding memory tge = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.TGE_1))];

        require(tge.end <= block.timestamp, IHost.WaitFundingEnd());

        bool success = tge.raised >= tge.minRaise;
        authority; // hide warning todo - use to deploy

        if (success) {
            // todo deploy token, xToken, staking, daoToken

            $.deployments[daoUid].token = address(0); // todo deployed token
            $.deployments[daoUid].xToken = address(0); // todo deployed xToken
            $.deployments[daoUid].staking = address(0); // todo deployed staking token
            $.deployments[daoUid].daoToken = address(0); // todo deployed daoToken

            // todo deploy vesting contracts and allocate token

            // todo seedToken holders became xToken holders by predefined rate

            // todo deploy v2 liquidity from TGE funds at predefined price
            return IDAOData.LifecyclePhase.LIVE_CLIFF_6;
        } else {
            return IDAOData.LifecyclePhase.DEVELOPMENT_4;
            // now refund can be called
            // refunding is available up to the start of next TGE
        }
    }

    /// @dev if any vesting started then phase changed
    function _changePhaseLiveCliff(
        HostLib.HostStorage storage $,
        uint daoUid
    ) internal view returns (IDAOData.LifecyclePhase) {
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

        return IDAOData.LifecyclePhase.LIVE_VESTING_7;
    }

    /// @dev if all vesting ended then phase changed
    function _changePhaseLiveVesting(
        HostLib.HostStorage storage $,
        uint daoUid
    ) internal view returns (IDAOData.LifecyclePhase) {
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

        return IDAOData.LifecyclePhase.LIVE_8;
    }
    //endregion -------------------------------------- Change phase utils
}
