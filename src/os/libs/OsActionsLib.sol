// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOS} from "../../interfaces/IOS.sol";
import {ITokenomics, IDAOUnit} from "../../interfaces/ITokenomics.sol";
import {OsLib} from "./OsLib.sol";
import {console} from "forge-std/console.sol";
import {IMintedERC20} from "../../interfaces/IMintedERC20.sol";
import {OsEncodingLib} from "./OsEncodingLib.sol";
import {IBurnableERC20} from "../../interfaces/IBurnableERC20.sol";

library OsActionsLib {
    using SafeERC20 for IERC20;

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
            dest.units[i] = $.units[OsLib.getKey(daoUid, i)];
        }

        // ------------------- agents
        dest.agents = new ITokenomics.AgentInfo[](data.countAgents);
        for (uint i; i < data.countAgents; i++) {
            dest.agents[i] = $.agents[OsLib.getKey(daoUid, i)];
        }

        { // ------------------- tokenomics
            OsLib.TokenomicsLocal memory tokenomics = $.tokenomics[daoUid];
            dest.tokenomics.initialChain = tokenomics.initialChain;

            dest.tokenomics.funding = new ITokenomics.Funding[](tokenomics.funding.length);
            for (uint i; i < dest.tokenomics.funding.length; i++) {
                dest.tokenomics.funding[i] = $.funding[OsLib.getKey(daoUid, i)];
            }

            dest.tokenomics.vesting = new ITokenomics.Vesting[](tokenomics.countVesting);
            for (uint i; i < tokenomics.countVesting; i++) {
                dest.tokenomics.vesting[i] = $.vesting[OsLib.getKey(daoUid, i)];
            }
        }

        return dest;
    }

    function getSettings() external view returns (IOS.OsSettings memory) {
        return OsLib.getOsStorage().osSettings[0];
    }

    function getChainSettings() external view returns (IOS.OsChainSettings memory) {
        return OsLib.getOsStorage().osChainSettings[0];
    }

    /// @notice Get list of pending tasks for the given DAO
    /// @param daoSymbol DAO symbol
    /// @param limit Maximum number of tasks to return. It must be > 0. Use 1 to check if there are any tasks.
    /// @return __tasks List of tasks. The list is limited by {limit} value
    function tasks(string calldata daoSymbol, uint limit) external view returns (IOS.Task[] memory __tasks) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        return _tasks(limit, $.daoUids[daoSymbol]);
    }

    function getDAOOwner(string calldata daoSymbol) external view returns (address) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];
        require(daoUid != 0, IOS.IncorrectDao());

        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;
        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            return $.daos[daoUid].deployer;
        }

        if (phase == ITokenomics.LifecyclePhase.SEED_1
            || phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3
            || phase == ITokenomics.LifecyclePhase.TGE_4
        ) {
            return $.deployments[daoUid].seedToken;
        }

        return $.deployments[daoUid].daoToken;
    }

    function isDaoSymbolInUse(string calldata daoSymbol) external view returns (bool) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        return $.usedSymbols[daoSymbol];
    }

    function proposal(bytes32 proposalId) external view returns (ITokenomics.Proposal memory) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        OsLib.ProposalLocal memory local = $.proposals[proposalId];
        return ITokenomics.Proposal({
            action: local.action,
            id: proposalId,
            daoSymbol: $.daos[local.daoUid].symbol,
            created: local.created,
            status: local.status,
            payload: local.payload
        });
    }

    function proposalsLength(string calldata daoSymbol) external view returns (uint) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        return $.daoProposals[$.daoUids[daoSymbol]].length;
    }

    function proposalIds(string calldata daoSymbol, uint index, uint count) external view returns (bytes32[] memory dest) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];
        uint len = $.daoProposals[$.daoUids[daoSymbol]].length;
        uint size = index + count > len
            ? index > len ? 0 : len - index
            : count;
        dest = new bytes32[](size);
        for (uint i = 0; i < size; i++) {
            dest[i] = $.daoProposals[daoUid][index + i];
        }
    }

    //endregion -------------------------------------- View

    //region -------------------------------------- Restricted actions
    function setSettings(IOS.OsSettings memory st) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        $.osSettings[0] = st;

        emit IOS.OsSettingsUpdated(st);
    }

    function setChainSettings(IOS.OsChainSettings memory st) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        $.osChainSettings[0] = st;

        emit IOS.OsChainSettingsUpdated(st);
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
            $.funding[OsLib.getKey(daoUid, i)] = funding[i];
        }

        _finalizeDaoCreation($, daoSymbol, name, daoUid);
    }

    /// @notice Add live DAO verified off-chain into the system
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
                $.funding[OsLib.getKey(daoUid, i)] = dao.tokenomics.funding[i];
            }
            for (uint i; i < dao.tokenomics.vesting.length; i++) {
                $.vesting[OsLib.getKey(daoUid, i)] = dao.tokenomics.vesting[i];
            }
        }

        for (uint i; i < dao.units.length; i++) {
            ITokenomics.UnitInfo storage unitInfo = $.units[OsLib.getKey(daoUid, i)];
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
            $.agents[OsLib.getKey(daoUid, i)] = dao.agents[i];
        }

        // todo do we need to register exit proposals?

        _finalizeDaoCreation($, dao.symbol, dao.name, daoUid);
    }

    /// @notice Change lifecycle phase of a DAO
    function changePhase(string calldata daoSymbol) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];

        require(_tasks(daoUid, 1).length == 0, IOS.SolveTasksFirst());

        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;
        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            ITokenomics.Funding memory seed = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
            require(seed.start < block.timestamp, IOS.WaitFundingStart());

            // SEED can be started not later than 1 week after configured start time
            require(block.timestamp <= seed.start + $.osSettings[0].maxSeedStartDelay, IOS.TooLateSoSetupFundingAgain());

            // todo deploy seedToken
            $.deployments[daoUid].seedToken = address(0); // todo deployed seed token

            $.daos[daoUid].phase = ITokenomics.LifecyclePhase.SEED_1;
            // todo emit event
        } else if (phase == ITokenomics.LifecyclePhase.SEED_1) {
            ITokenomics.Funding memory seed = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
            require(seed.end <= block.timestamp, IOS.WaitFundingEnd());

            bool success = seed.raised >= seed.minRaise;

            if (success) {
                $.daos[daoUid].phase = ITokenomics.LifecyclePhase.DEVELOPMENT_3;
            } else {
                $.daos[daoUid].phase = ITokenomics.LifecyclePhase.SEED_FAILED_2;
                // now refund can be called
            }
            // todo emit event
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            ITokenomics.Funding memory tge = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

            require(tge.start <= block.timestamp, IOS.WaitFundingStart());

            // todo deploy tgeToken
            $.deployments[daoUid].tgeToken = address(0); // todo deployed tge token

            $.daos[daoUid].phase = ITokenomics.LifecyclePhase.TGE_4;
            // todo emit event
        } else if (phase == ITokenomics.LifecyclePhase.TGE_4) {
            ITokenomics.Funding memory tge = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

            require(tge.end < block.timestamp, IOS.WaitFundingEnd());

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
                $.daos[daoUid].phase = ITokenomics.LifecyclePhase.LIVE_CLIFF_5;
                // todo emit event
            } else {
                $.daos[daoUid].phase = ITokenomics.LifecyclePhase.DEVELOPMENT_3;
                // todo emit event
                // now refund can be called
                // refunding is available up to the start of next TGE
            }
        } else if (phase == ITokenomics.LifecyclePhase.LIVE_CLIFF_5) {
            // if any vesting started then phase changed

            // slither-disable-next-line uninitialized-local
            bool isVestingStarted;

            uint countVesting = $.tokenomics[daoUid].countVesting;
            for (uint i; i < countVesting; i++) {
                if ($.vesting[OsLib.getKey(daoUid, i)].start < block.timestamp) {
                    isVestingStarted = true;
                    break;
                }
            }

            require(isVestingStarted, IOS.WaitVestingStart());

            $.daos[daoUid].phase = ITokenomics.LifecyclePhase.LIVE_VESTING_6;
            // todo emit event
        } else if (phase == ITokenomics.LifecyclePhase.LIVE_VESTING_6) {
            // slither-disable-next-line uninitialized-local
            bool isVestingNotEnded;

            uint countVesting = $.tokenomics[daoUid].countVesting;
            for (uint i; i < countVesting; i++) {
                if ($.vesting[OsLib.getKey(daoUid, i)].end <= block.timestamp) {
                    isVestingNotEnded = true;
                    break;
                }
            }

            require(isVestingNotEnded, IOS.WaitVestingEnd());

            $.daos[daoUid].phase = ITokenomics.LifecyclePhase.LIVE_7;
            // todo emit event
        }
    }

    /// @notice Fund DAO in the current funding round
    function fund(string calldata daoSymbol, uint amount) external {  // todo not reentrancy
        require(amount != 0, IOS.ZeroAmount()); // todo settings.minFunding

        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];

        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;

        if (phase == ITokenomics.LifecyclePhase.SEED_1) {
            ITokenomics.Funding storage seed = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];

            require(seed.raised + amount < seed.maxRaise, IOS.RaiseMaxExceed());

            // transfer amount of exchangeAsset to seedToken contract
            address seedToken = $.deployments[daoUid].seedToken;
            IERC20($.osChainSettings[0].exchangeAsset).safeTransferFrom(msg.sender, seedToken, amount);

            seed.raised += amount;

            // mint seedToken to user
            IMintedERC20(seedToken).mint(msg.sender, amount);

            emit IOS.DaoFunded(daoSymbol, msg.sender, amount, uint8(ITokenomics.FundingType.SEED_0));

        } else if (phase == ITokenomics.LifecyclePhase.TGE_4) {
            ITokenomics.Funding storage tge = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

            require(tge.raised + amount < tge.maxRaise, IOS.RaiseMaxExceed());

            // transfer amount of exchangeAsset to tgeToken contract
            address tgeToken = $.deployments[daoUid].tgeToken;
            IERC20($.osChainSettings[0].exchangeAsset).safeTransferFrom(msg.sender, tgeToken, amount);

            tge.raised += amount;

            // record msg.sender as funder with amount
            IMintedERC20(tgeToken).mint(msg.sender, amount);

            emit IOS.DaoFunded(daoSymbol, msg.sender, amount, uint8(ITokenomics.FundingType.TGE_1));
        } else {
            revert IOS.NotFundingPhase();
        }
    }

    /// @notice Receive voting results from voting module and execute proposal if approved
    function receiveVotingResults(bytes32 proposalId, bool succeed) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();

        OsLib.ProposalLocal storage p = $.proposals[proposalId];

        require(p.daoUid != 0, IOS.IncorrectProposal());
        require(p.status == ITokenomics.VotingStatus.VOTING_0, IOS.AlreadyReceived());

        p.status = succeed ? ITokenomics.VotingStatus.APPROVED_1 : ITokenomics.VotingStatus.REJECTED_2;

        ITokenomics.DAOAction action = p.action;
        if (succeed) {
            if (action == ITokenomics.DAOAction.UPDATE_IMAGES_0) {
                OsLib.updateImages(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_SOCIALS_1) {
                OsLib.updateSocials(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_UNITS_3) {
                OsLib.updateUnits(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_FUNDING_4) {
                OsLib.updateFunding(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_VESTING_5) {
                OsLib.updateVesting(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_NAMING_2) {
                OsLib.updateNaming(p.daoUid, p.payload);
            } else if (action == ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6) {
                OsLib.updateDaoParameters(p.daoUid, p.payload);
            } else {
                // todo other actions
                revert IOS.NonImplemented();
            }
        }
    }

    /// @notice Refund funding to the SEED/TGE token holders if funding round failed
    /// Anybody can call this function to refund his own tokens
    /// SEED token can be returned only on SEED_FAILED phase
    /// TGE token can be returned only on DEVELOPMENT phase
    function refund(string calldata daoSymbol) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];
        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;

        address asset = $.osChainSettings[0].exchangeAsset;
        if (phase == ITokenomics.LifecyclePhase.SEED_FAILED_2) {
            address seedToken = $.deployments[daoUid].seedToken;
            _refundFunding(daoSymbol, ITokenomics.FundingType.SEED_0, msg.sender, seedToken, asset, false);
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            address tgeToken = $.deployments[daoUid].tgeToken;
            _refundFunding(daoSymbol, ITokenomics.FundingType.TGE_1, msg.sender, tgeToken, asset, false);
        } else {
            revert IOS.NotRefundPhase();
        }
    }

    /// @notice Refund funding to the SEED/TGE token holders if funding round failed
    /// Anybody can call this function to make refund of first {limit} token holders
    /// SEED token can be returned only on SEED_FAILED phase
    /// TGE token can be returned only on DEVELOPMENT phase
    function refundFor(string calldata daoSymbol, address[] memory receivers) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];
        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;

        address asset = $.osChainSettings[0].exchangeAsset;
        if (phase == ITokenomics.LifecyclePhase.SEED_FAILED_2) {
            address seedToken = $.deployments[daoUid].seedToken;
            for (uint i; i < receivers.length; i++) {
                _refundFunding(daoSymbol, ITokenomics.FundingType.SEED_0, receivers[i], seedToken, asset, true);
            }
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            address tgeToken = $.deployments[daoUid].tgeToken;
            for (uint i; i < receivers.length; i++) {
                _refundFunding(daoSymbol, ITokenomics.FundingType.TGE_1, receivers[i], tgeToken, asset, true);
            }
        } else {
            revert IOS.NotRefundPhase();
        }
    }
    //endregion -------------------------------------- Actions

    //region -------------------------------------- Update logic
    function _beforeUpdate(string memory daoSymbol) internal view returns (
        OsLib.OsStorage storage $,
        uint daoUid,
        bool instantExecute,
        ITokenomics.LifecyclePhase phase
    ) {
        $ = OsLib.getOsStorage();
        daoUid = $.daoUids[daoSymbol];
        phase = $.daos[daoUid].phase;
        require(daoUid != 0, IOS.IncorrectDao());
        instantExecute = phase != ITokenomics.LifecyclePhase.DRAFT_0;
        if (instantExecute) {
            require($.daos[daoUid].deployer == msg.sender, IOS.YouAreNotOwnerOf(daoSymbol));
        }
    }

    /// @notice Update/create proposal to update implementations of the DAO contracts
    function updateImages(string memory daoSymbol, ITokenomics.DaoImages memory images) internal {
        (, uint daoUid, bool instantExecute, ) = _beforeUpdate(daoSymbol);

        bytes memory payload = OsEncodingLib.encodeDaoImages(images, OsEncodingLib.DAO_IMAGES_STRUCT_VERSION);
        if (instantExecute) {
            OsLib.updateImages(daoUid, payload);
        } else {
            OsLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_IMAGES_0, payload);
        }
    }

    /// @notice Update/create proposal to update list of socials of the DAO
    function updateSocials(string memory daoSymbol, string[] memory socials) internal {
        (, uint daoUid, bool instantExecute, ) = _beforeUpdate(daoSymbol);

        bytes memory payload = OsEncodingLib.encodeSocials(socials);
        if (instantExecute) {
            OsLib.updateSocials(daoUid, payload);
        } else {
            OsLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_SOCIALS_1, payload);
        }
    }

    /// @notice Update/create proposal to update tokenomics units of the DAO
    function updateUnits(string memory daoSymbol, ITokenomics.UnitInfo[] memory units) internal {
        (, uint daoUid, bool instantExecute, ) = _beforeUpdate(daoSymbol);

        bytes memory payload = OsEncodingLib.encodeUnits(units, OsEncodingLib.UNIT_STRUCT_VERSION);
        if (instantExecute) {
            OsLib.updateUnits(daoUid, payload);
        } else {
            OsLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_UNITS_3, payload);
        }
    }

    /// @notice Update/create proposal to update funding rounds of the DAO
    function updateFunding(string memory daoSymbol, ITokenomics.Funding memory funding) internal {
        (OsLib.OsStorage storage $, uint daoUid, bool instantExecute, ITokenomics.LifecyclePhase phase) = _beforeUpdate(daoSymbol);

        OsLib._validateFunding(phase, funding, $.osSettings[0]);

        bytes memory payload = OsEncodingLib.encodeFunding(funding, OsEncodingLib.FUNDING_STRUCT_VERSION);
        if (instantExecute) {
            OsLib.updateFunding(daoUid, payload);
        } else {
            OsLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_FUNDING_4, payload);
        }
    }

    /// @notice Update/create proposal to update vesting schedules of the DAO
    function updateVesting(string memory daoSymbol, ITokenomics.Vesting[] memory vesting) internal {
        (OsLib.OsStorage storage $, uint daoUid, bool instantExecute, ITokenomics.LifecyclePhase phase) = _beforeUpdate(daoSymbol);

        OsLib._validateVestingList(phase, vesting, $.osSettings[0]);

        bytes memory payload = OsEncodingLib.encodeVesting(vesting, OsEncodingLib.VESTING_STRUCT_VERSION);
        if (instantExecute) {
            OsLib.updateVesting(daoUid, payload);
        } else {
            OsLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_VESTING_5, payload);
        }
    }

    /// @notice Update/create proposal to update DAO naming (name and symbol)
    function updateNaming(string memory daoSymbol, ITokenomics.DaoNames memory daoNames_) internal {
        (OsLib.OsStorage storage $, uint daoUid, bool instantExecute, ) = _beforeUpdate(daoSymbol);

        OsLib._validateNaming(daoNames_.name, daoNames_.symbol, $.osSettings[0]);

        bytes memory payload = OsEncodingLib.encodeDaoNames(daoNames_, OsEncodingLib.DAO_NAMES_STRUCT_VERSION);
        if (instantExecute) {
            OsLib.updateNaming(daoUid, payload);
        } else {
            OsLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_NAMING_2, payload);
        }
    }

    /// @notice Update/create proposal to update on-chain DAO parameters
    function updateDaoParameters(string memory daoSymbol, ITokenomics.DaoParameters memory daoParameters_) internal {
        (OsLib.OsStorage storage $, uint daoUid, bool instantExecute, ) = _beforeUpdate(daoSymbol);

        OsLib._validateDaoParameters(daoParameters_, $.osSettings[0]);

        bytes memory payload = OsEncodingLib.encodeDaoParameters(daoParameters_, OsEncodingLib.DAO_PARAMETERS_STRUCT_VERSION);
        if (instantExecute) {
            OsLib.updateDaoParameters(daoUid, payload);
        } else {
            OsLib.proposeAction(daoUid, ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6, payload);
        }
    }

    //endregion -------------------------------------- Update logic

    //region -------------------------------------- Internal logic
    function _refundFunding(
        string calldata daoSymbol,
        ITokenomics.FundingType fundingType_,
        address receiver,
        address fundingToken,
        address exchangeAsset,
        bool skipOnZeroBalance
    ) internal {
        uint balance = IERC20(fundingToken).balanceOf(receiver);
        if (balance == 0) {
            require(skipOnZeroBalance, IOS.ZeroBalance());
        } else {
            // burn SEED tokens
            // todo IBurnableERC20(seedToken).burn(receiver, balance);

            // transfer exchangeAsset back to receiver
            IERC20(exchangeAsset).safeTransferFrom(fundingToken, receiver, balance);

            emit IOS.DaoRefunded(daoSymbol, receiver, balance, uint8(fundingType_));
        }
    }

    function _tasks(uint limit, uint daoUid) internal view returns (IOS.Task[] memory dest) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        dest = new IOS.Task[](limit);

        // slither-disable-next-line uninitialized-local
        uint index;

        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;

        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            ITokenomics.DaoImages memory daoImages = $.daoImages[daoUid];
            if (index < limit && (bytes(daoImages.seedToken).length == 0 || bytes(daoImages.token).length == 0)) {
                dest[index++] = IOS.Task("Need images of token and seedToken");
            }
            if (index < limit && $.daos[daoUid].socials.length < 2) {
                dest[index++] = IOS.Task("Need at least 2 socials");
            }
            if (index < limit && $.daos[daoUid].countUnits == 0) {
                dest[index++] = IOS.Task("Need at least 1 projected unit");
            }
        } else if (phase == ITokenomics.LifecyclePhase.SEED_1) {
            ITokenomics.Funding memory f = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
            if (f.fundingType == ITokenomics.FundingType.SEED_0) { // todo check if funding round exists. Can SEED_0 be skipped? if yes we need different way to check if it exists
                if (index < limit && f.raised < f.minRaise && f.end > block.timestamp) {
                    dest[index++] = IOS.Task("Need attract minimal seed funding");
                }
            }
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            ITokenomics.Funding memory f = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
            if (index < limit && f.fundingType != ITokenomics.FundingType.TGE_1) {
                dest[index++] = IOS.Task("Need add pre-TGE funding");
            }
            ITokenomics.DaoImages memory daoImages = $.daoImages[daoUid];
            if (index < limit && bytes(daoImages.tgeToken).length == 0 || bytes(daoImages.xToken).length == 0 || bytes(daoImages.daoToken).length == 0) {
                dest[index++] = IOS.Task("Need images of all DAO tokens");
            }
            if (index < limit && $.tokenomics[daoUid].countVesting == 0) {
                dest[index++] = IOS.Task("Need vesting allocations");
            }
            uint countUnits = $.daos[daoUid].countUnits;

            // slither-disable-next-line uninitialized-local
            bool foundLive;

            for (uint i; i < countUnits; i++) {
                ITokenomics.UnitInfo memory unit = $.units[OsLib.getKey(daoUid, i)];
                if (unit.status == IDAOUnit.UnitStatus.LIVE_2) {
                    foundLive = true;
                    break;
                }
            }
            if (index < limit && !foundLive) {
                dest[index++] = IOS.Task("Run revenue generating units");
            }

        } else if (phase == ITokenomics.LifecyclePhase.TGE_4) {
            ITokenomics.Funding memory f = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
            if (index < limit && f.raised < f.minRaise && f.end > block.timestamp) {
                dest[index++] = IOS.Task("Need attract minimal TGE funding");
            }
        } else if (phase == ITokenomics.LifecyclePhase.LIVE_CLIFF_5) {
            // establish and improve
            // build money markets
            // bridge to chains
        } else if (phase == ITokenomics.LifecyclePhase.LIVE_VESTING_6) {
            // distribute vesting funds to leverage token
        } else if (phase == ITokenomics.LifecyclePhase.LIVE_7) {
            // lifetime revenue generating for DAO holders till possible absorbing
        }

        return dest;
    }


    /// @notice Mark DAO symbol as used and emit events
    function _finalizeDaoCreation(OsLib.OsStorage storage $, string memory daoSymbol, string memory daoName, uint daoUid) internal {
        $.usedSymbols[daoSymbol] = true;

        emit IOS.DaoCreated(daoName, daoSymbol, daoUid);

        OsLib._sendCrossChainMessage(IOS.CrossChainMessages.NEW_DAO_SYMBOL_0, OsEncodingLib.encodeSymbol(daoSymbol));
    }
    //endregion -------------------------------------- Internal logic

    //region -------------------------------------- Internal utils
    //endregion -------------------------------------- Internal utils


}