// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {HostLib} from "./HostLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {HostDeployLib} from "./HostDeployLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library HostViewLib {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

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
    function changePhase(string calldata daoSymbol, address authority) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = $.daoUids[daoSymbol];

        require(daoUid != 0, IHost.IncorrectDao());
        require(_tasks(1, daoUid).length == 0, IHost.SolveTasksFirst());

        ITokenomics.LifecyclePhase phase = $.segment2[daoUid].phase;
        ITokenomics.LifecyclePhase newPhase = phase;

        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
            require(seed.start < block.timestamp, IHost.WaitFundingStart());

            // SEED can be started not later than 1 week after configured start time
            require(
                block.timestamp <= seed.start + HostConfigLib.getHostGlobalSettings().maxSeedStartDelay,
                IHost.TooLateSoSetupFundingAgain()
            );

            $.deployments[daoUid].seedToken = HostDeployLib.deploySeedToken(
                $,
                daoUid,
                getTokenName($.segment2[daoUid].name, uint(NamingTokenKind.SEED_0)),
                getTokenSymbol(daoSymbol, uint(NamingTokenKind.SEED_0)),
                authority
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
                daoUid,
                getTokenName($.segment2[daoUid].name, uint(NamingTokenKind.TGE_1)),
                getTokenSymbol(daoSymbol, uint(NamingTokenKind.TGE_1)),
                authority
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
            bool isVestingNotEnded;

            uint countVesting = $.segment3[daoUid].countVesting;
            for (uint i; i < countVesting; i++) {
                if ($.vesting[HostLib.getKey(daoUid, i)].end <= block.timestamp) {
                    isVestingNotEnded = true;
                    break;
                }
            }

            require(isVestingNotEnded, IHost.WaitVestingEnd());

            newPhase = ITokenomics.LifecyclePhase.LIVE_7;
        }

        $.segment2[daoUid].phase = newPhase;

        emit IHost.DaoPhaseChanged(daoSymbol, newPhase);
    }

    //region -------------------------------------- View
    /// @notice Get full on-chain DAO data by its symbol.
    function getDAO(string calldata daoSymbol) external view returns (IDAOData.DaoData memory dest) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        dest.uid = $.daoUids[daoSymbol];

        HostLib.DaoDataSegment2 memory segment2 = $.segment2[dest.uid];
        HostLib.DaoDataSegment3 memory segment3 = $.segment3[dest.uid];

        { // ------------------- basic fields

            dest.symbol = segment2.daoSymbol;
            dest.name = segment2.name;
            dest.phase = segment2.phase;

            dest.deployer = segment3.deployer;

            dest.socials = $.segment3[dest.uid].socials;
            dest.activity = $.segment3[dest.uid].activity;
        }

        { // ------------------- images, deployments, params
            dest.images = $.daoImages[dest.uid];
            dest.deployments = $.deployments[dest.uid];
            dest.params = $.daoParameters[dest.uid];
        }

        // ------------------- units
        dest.units = new IDAOData.UnitData[](segment2.hashUnitIds.length);
        for (uint i; i < dest.units.length; i++) {
            HostLib.UnitLocal storage unit = $.units[segment2.hashUnitIds[i]];
            dest.units[i].unitId = unit.unitId;
            dest.units[i].developerUid = unit.developerUid;
            dest.units[i].chainIds = unit.chainIds.values();
        }

        { // ------------------- tokenomics
            dest.initialChain = segment3.initialChain;

            dest.funding = new ITokenomics.Funding[](segment3.funding.length);
            for (uint i; i < dest.funding.length; i++) {
                dest.funding[i] = $.funding[HostLib.getIndexKey(dest.uid, i)];
            }

            dest.vesting = new ITokenomics.Vesting[](segment3.countVesting);
            for (uint i; i < dest.vesting.length; i++) {
                dest.vesting[i] = $.vesting[HostLib.getIndexKey(dest.uid, i)];
            }
        }

        return dest;
    }

    /// @notice Get Host DAO UID
    function getHostDaoUid() external view returns (uint) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        return $.hostDaoUid;
    }

    /// @notice Get Host global settings
    function getSettings() external view returns (IHost.HostSettings memory) {
        return HostConfigLib.getHostGlobalSettings();
    }

    /// @notice Get Host chain settings
    function getChainSettings() external view returns (IHost.HostChainSettings memory) {
        return HostConfigLib.getHostChainSettings();
    }

    /// @notice Get owner of the DAO depending on its lifecycle phase
    function getDAOOwner(string calldata daoSymbol) external view returns (address) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = $.daoUids[daoSymbol];
        require(daoUid != 0, IHost.IncorrectDao());

        ITokenomics.LifecyclePhase phase = $.segment2[daoUid].phase;
        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            return $.segment3[daoUid].deployer;
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
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        return $.daoUids[daoSymbol] != 0;
    }

    function proposal(bytes32 proposalId) external view returns (ITokenomics.Proposal memory) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.ProposalLocal memory local = $.proposals[proposalId];
        return ITokenomics.Proposal({
            action: local.action,
            id: proposalId,
            daoSymbol: $.segment2[local.daoUid].daoSymbol,
            created: local.created,
            status: local.status,
            payload: local.payload
        });
    }

    function proposalsLength(string calldata daoSymbol) external view returns (uint) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        return $.daoProposals[$.daoUids[daoSymbol]].length;
    }

    function proposalIds(
        string calldata daoSymbol,
        uint index,
        uint count
    ) external view returns (bytes32[] memory dest) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
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
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
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
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = $.daoUids[daoSymbol];
        return $.unitBalances[HostLib.getUnitKey(daoUid, unitId)];
    }

    function salt(string calldata daoSymbol, uint16 contractIndex, uint chainId) external view returns (bytes32) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = $.daoUids[daoSymbol];
        return $.salt[HostLib.getKey(daoUid, contractIndex, chainId == 0 ? block.chainid : chainId)];
    }
    //endregion -------------------------------------- View

    function _tasks(uint16 limit, uint daoUid) internal view returns (IHost.Task[] memory dest) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        dest = new IHost.Task[](limit);

        // slither-disable-next-line uninitialized-local
        uint index;

        ITokenomics.LifecyclePhase phase = $.segment2[daoUid].phase;

        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            ITokenomics.DaoImages memory daoImages = $.daoImages[daoUid];
            if (index < limit && (bytes(daoImages.seedToken).length == 0 || bytes(daoImages.token).length == 0)) {
                dest[index++] = IHost.Task("Need images of token and seedToken");
            }
            if (index < limit && $.segment3[daoUid].socials.length < 2) {
                dest[index++] = IHost.Task("Need at least 2 socials");
            }
            if (index < limit && $.segment2[daoUid].hashUnitIds.length == 0) {
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
            if (index < limit && $.segment3[daoUid].countVesting == 0) {
                dest[index++] = IHost.Task("Need vesting allocations");
            }
            bytes32[] memory hashUnitIds = $.segment2[daoUid].hashUnitIds;

            // slither-disable-next-line uninitialized-local
            bool foundLive;

            // assume that a unit is live if it has received not zero income
            for (uint i; i < hashUnitIds.length; i++) {
                // todo do we need to use a threshold here?
                if ($.unitBalances[hashUnitIds[i]] != 0) {
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
