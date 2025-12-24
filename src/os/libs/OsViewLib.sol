// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOS} from "../../interfaces/IOS.sol";
import {ITokenomics, IDAOUnit} from "../../interfaces/ITokenomics.sol";
import {OsLib} from "./OsLib.sol";
import {console} from "forge-std/console.sol";
import {OsDeployLib} from "./OsDeployLib.sol";

library OsViewLib {
    using SafeERC20 for IERC20;

    /// @notice Change lifecycle phase of a DAO
    /// @param daoSymbol Symbol of the DAO
    /// @param authority_ Address of Access Manager
    function changePhase(string calldata daoSymbol, address authority_) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];

        require(_tasks(daoUid, 1).length == 0, IOS.SolveTasksFirst());

        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;
        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            ITokenomics.Funding memory seed = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
            console.log("changePhase", seed.start, block.timestamp);
            require(seed.start < block.timestamp, IOS.WaitFundingStart());

            // SEED can be started not later than 1 week after configured start time
            require(block.timestamp <= seed.start + $.osSettings[0].maxSeedStartDelay, IOS.TooLateSoSetupFundingAgain());

            $.deployments[daoUid].seedToken = OsDeployLib.deploySeedToken(
                authority_, string(abi.encodePacked("Seed ", daoSymbol)), string(abi.encodePacked("seed", daoSymbol))
            );

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

            $.deployments[daoUid].tgeToken = OsDeployLib.deployTgeToken(
                authority_, string(abi.encodePacked("Tge ", daoSymbol)), string(abi.encodePacked("tge", daoSymbol))
            );

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

    function getDAOOwner(string calldata daoSymbol) external view returns (address) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];
        require(daoUid != 0, IOS.IncorrectDao());

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

    function proposalIds(
        string calldata daoSymbol,
        uint index,
        uint count
    ) external view returns (bytes32[] memory dest) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
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
    function tasks(string calldata daoSymbol, uint limit) external view returns (IOS.Task[] memory __tasks) {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        return _tasks(limit, $.daoUids[daoSymbol]);
    }
    //endregion -------------------------------------- View

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
            if (f.fundingType == ITokenomics.FundingType.SEED_0) {
                // todo check if funding round exists. Can SEED_0 be skipped? if yes we need different way to check if it exists
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
            if (
                index < limit && bytes(daoImages.tgeToken).length == 0 || bytes(daoImages.xToken).length == 0
                    || bytes(daoImages.daoToken).length == 0
            ) {
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

        // trim the dest array
        if (index < dest.length) {
            IOS.Task[] memory temp = new IOS.Task[](index);

            for (uint i; i < index; ++i) {
                temp[i] = dest[i];
            }

            dest = temp;
        }

        return dest;
    }
}
