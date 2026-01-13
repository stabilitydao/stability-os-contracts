// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHost} from "../interfaces/IHost.sol";
import {ITokenomics, IDAOUnit} from "../interfaces/ITokenomics.sol";
import {HostLib} from "./HostLib.sol";
import {HostDeployLib} from "./HostDeployLib.sol";

library HostViewLib {
    using SafeERC20 for IERC20;

    /// @notice Token kind for getTokenName and getTokenSymbol
    enum NamingTokenKind {
        SEED_0,
        TGE_1,
        TOKEN_2,
        XTOKEN_3,
        DAO_4
    }

    /// @notice Change lifecycle phase of a DAO
    /// @param daoSymbol Symbol of the DAO
    function changePhase(string calldata daoSymbol) external {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];

        require(_tasks(1, daoUid).length == 0, IHost.SolveTasksFirst());

        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;
        ITokenomics.LifecyclePhase newPhase = phase;

        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
            require(seed.start < block.timestamp, IHost.WaitFundingStart());

            // SEED can be started not later than 1 week after configured start time
            require(
                block.timestamp <= seed.start + $.osSettings[0].maxSeedStartDelay, IHost.TooLateSoSetupFundingAgain()
            );

            $.deployments[daoUid].seedToken = HostDeployLib.deploySeedToken(
                $,
                getTokenName($.daos[daoUid].name, uint(NamingTokenKind.SEED_0)),
                getTokenSymbol(daoSymbol, uint(NamingTokenKind.SEED_0))
            );

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

            $.deployments[daoUid].tgeToken = HostDeployLib.deployTgeToken(
                $,
                getTokenName($.daos[daoUid].name, uint(NamingTokenKind.TGE_1)),
                getTokenSymbol(daoSymbol, uint(NamingTokenKind.TGE_1))
            );

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

            uint countVesting = $.tokenomics[daoUid].countVesting;
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
            bool isVestingNotEnded;

            uint countVesting = $.tokenomics[daoUid].countVesting;
            for (uint i; i < countVesting; i++) {
                if ($.vesting[HostLib.getKey(daoUid, i)].end <= block.timestamp) {
                    isVestingNotEnded = true;
                    break;
                }
            }

            require(isVestingNotEnded, IHost.WaitVestingEnd());

            newPhase = ITokenomics.LifecyclePhase.LIVE_7;
        }

        $.daos[daoUid].phase = newPhase;

        emit IHost.DaoPhaseChanged(daoSymbol, newPhase);
    }

    //region -------------------------------------- View
    function getDAO(string calldata daoSymbol) external view returns (ITokenomics.DaoData memory) {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();

        uint daoUid = $.daoUids[daoSymbol];

        ITokenomics.DaoData memory dest;
        HostLib.DaoDataLocal memory data = $.daos[daoUid];

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
            dest.units[i] = $.units[HostLib.getKey(daoUid, i)];
        }

        // ------------------- agents
        dest.agents = new ITokenomics.AgentInfo[](data.countAgents);
        for (uint i; i < data.countAgents; i++) {
            dest.agents[i] = $.agents[HostLib.getKey(daoUid, i)];
        }

        { // ------------------- tokenomics
            HostLib.TokenomicsLocal memory tokenomics = $.tokenomics[daoUid];
            dest.tokenomics.initialChain = tokenomics.initialChain;

            dest.tokenomics.funding = new ITokenomics.Funding[](tokenomics.funding.length);
            for (uint i; i < dest.tokenomics.funding.length; i++) {
                dest.tokenomics.funding[i] = $.funding[HostLib.getKey(daoUid, i)];
            }

            dest.tokenomics.vesting = new ITokenomics.Vesting[](tokenomics.countVesting);
            for (uint i; i < tokenomics.countVesting; i++) {
                dest.tokenomics.vesting[i] = $.vesting[HostLib.getKey(daoUid, i)];
            }
        }

        return dest;
    }

    function getSettings() external view returns (IHost.HostSettings memory) {
        return HostLib.getOsStorage().osSettings[0];
    }

    function getChainSettings() external view returns (IHost.HostChainSettings memory) {
        return HostLib.getOsStorage().osChainSettings[0];
    }

    function getDAOOwner(string calldata daoSymbol) external view returns (address) {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];
        require(daoUid != 0, IHost.IncorrectDao());

        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;
        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            return $.daos[daoUid].deployer;
        }

        if (
            phase == ITokenomics.LifecyclePhase.SEED_1 || phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3
                || phase == ITokenomics.LifecyclePhase.TGE_4
        ) {
            return $.deployments[daoUid].seedToken;
        }

        return $.deployments[daoUid].daoToken;
    }

    function isDaoSymbolInUse(string calldata daoSymbol) external view returns (bool) {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        return $.usedSymbols[daoSymbol];
    }

    function proposal(bytes32 proposalId) external view returns (ITokenomics.Proposal memory) {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        HostLib.ProposalLocal memory local = $.proposals[proposalId];
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
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        return $.daoProposals[$.daoUids[daoSymbol]].length;
    }

    function proposalIds(
        string calldata daoSymbol,
        uint index,
        uint count
    ) external view returns (bytes32[] memory dest) {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];
        uint len = $.daoProposals[$.daoUids[daoSymbol]].length;
        uint size = index + count > len ? index > len ? 0 : len - index : count;
        dest = new bytes32[](size);
        for (uint i = 0; i < size; i++) {
            dest[i] = $.daoProposals[daoUid][index + i];
        }
    }

    /// @notice Get list of pending tasks for the given DAO
    /// @param daoSymbol DAO symbol
    /// @param limit Maximum number of tasks to return. It must be > 0. Use 1 to check if there are any tasks.
    /// @return __tasks List of tasks. The list is limited by {limit} value
    function tasks(string calldata daoSymbol, uint limit) external view returns (IHost.Task[] memory __tasks) {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        return _tasks(uint16(limit), $.daoUids[daoSymbol]);
    }

    /// @notice Generate token name in same way as getTokensNaming()
    /// @param name dao name
    /// @param kind token kind, see NamingTokenKind: 0 - seed, 1 - tge, 2 - main token, 3 - x-token, 4 - dao token
    function getTokenName(string memory name, uint kind) internal pure returns (string memory) {
        if (kind == uint(NamingTokenKind.SEED_0)) {
            return string(abi.encodePacked(name, " SEED"));
        } else if (kind == uint(NamingTokenKind.TGE_1)) {
            return string(abi.encodePacked(name, " PRESALE"));
        } else if (kind == uint(NamingTokenKind.TOKEN_2)) {
            return name;
        } else if (kind == uint(NamingTokenKind.XTOKEN_3)) {
            return string(abi.encodePacked("x", name));
        } else if (kind == uint(NamingTokenKind.DAO_4)) {
            return string(abi.encodePacked(name, " DAO"));
        }
        return "";
    }

    /// @notice Generate token symbol in same way as getTokensNaming()
    /// @param symbol dao symbol
    /// @param kind token kind, see NamingTokenKind: 0 - seed, 1 - tge, 2 - main token, 3 - x-token, 4 - dao token
    function getTokenSymbol(string memory symbol, uint kind) internal pure returns (string memory) {
        if (kind == uint(NamingTokenKind.SEED_0)) {
            return string(abi.encodePacked("seed", symbol));
        } else if (kind == uint(NamingTokenKind.TGE_1)) {
            return string(abi.encodePacked("sale", symbol));
        } else if (kind == uint(NamingTokenKind.TOKEN_2)) {
            return symbol;
        } else if (kind == uint(NamingTokenKind.XTOKEN_3)) {
            return string(abi.encodePacked("x", symbol));
        } else if (kind == uint(NamingTokenKind.DAO_4)) {
            return string(abi.encodePacked(symbol, "_DAO"));
        }
        return "";
    }

    /// @notice Get balance of the given unit for the given DAO
    function unitBalance(string calldata daoSymbol, string calldata unitId) external view returns (uint) {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];
        return $.unitBalances[HostLib.getKey(daoUid, unitId)];
    }
    //endregion -------------------------------------- View

    function _tasks(uint16 limit, uint daoUid) internal view returns (IHost.Task[] memory dest) {
        HostLib.OsStorage storage $ = HostLib.getOsStorage();
        dest = new IHost.Task[](limit);

        // slither-disable-next-line uninitialized-local
        uint index;

        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;

        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            ITokenomics.DaoImages memory daoImages = $.daoImages[daoUid];
            if (index < limit && (bytes(daoImages.seedToken).length == 0 || bytes(daoImages.token).length == 0)) {
                dest[index++] = IHost.Task("Need images of token and seedToken");
            }
            if (index < limit && $.daos[daoUid].socials.length < 2) {
                dest[index++] = IHost.Task("Need at least 2 socials");
            }
            if (index < limit && $.daos[daoUid].countUnits == 0) {
                dest[index++] = IHost.Task("Need at least 1 projected unit");
            }
        } else if (phase == ITokenomics.LifecyclePhase.SEED_1) {
            ITokenomics.Funding memory f = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
            if (f.fundingType == ITokenomics.FundingType.SEED_0) {
                // todo check if funding round exists. Can SEED_0 be skipped? if yes we need different way to check if it exists
                if (index < limit && f.raised < f.minRaise && f.end > block.timestamp) {
                    dest[index++] = IHost.Task("Need attract minimal seed funding");
                }
            }
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            ITokenomics.Funding memory f = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
            if (index < limit && f.fundingType != ITokenomics.FundingType.TGE_1) {
                dest[index++] = IHost.Task("Need add pre-TGE funding");
            }
            ITokenomics.DaoImages memory daoImages = $.daoImages[daoUid];
            if (
                index < limit && bytes(daoImages.tgeToken).length == 0 || bytes(daoImages.xToken).length == 0
                    || bytes(daoImages.daoToken).length == 0
            ) {
                dest[index++] = IHost.Task("Need images of all DAO tokens");
            }
            if (index < limit && $.tokenomics[daoUid].countVesting == 0) {
                dest[index++] = IHost.Task("Need vesting allocations");
            }
            uint countUnits = $.daos[daoUid].countUnits;

            // slither-disable-next-line uninitialized-local
            bool foundLive;

            for (uint i; i < countUnits; i++) {
                ITokenomics.UnitInfo memory unit = $.units[HostLib.getKey(daoUid, i)];
                if (unit.status == IDAOUnit.UnitStatus.LIVE_2) {
                    foundLive = true;
                    break;
                }
            }
            if (index < limit && !foundLive) {
                dest[index++] = IHost.Task("Run revenue generating units");
            }
        } else if (phase == ITokenomics.LifecyclePhase.TGE_4) {
            ITokenomics.Funding memory f = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
            if (index < limit && f.raised < f.minRaise && f.end > block.timestamp) {
                dest[index++] = IHost.Task("Need attract minimal TGE funding");
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

        // trim the dest array
        if (index < dest.length) {
            IHost.Task[] memory temp = new IHost.Task[](index);

            for (uint i; i < index; ++i) {
                temp[i] = dest[i];
            }

            dest = temp;
        }

        return dest;
    }
}
