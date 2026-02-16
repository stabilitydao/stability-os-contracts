// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {HostEncodingLib} from "./HostEncodingLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {HostLib} from "./HostLib.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {IHost} from "../interfaces/IHost.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";

/// @notice Library with view functions for Host contract
library HostViewLib {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    //region -------------------------------------- View
    function getDataReaderItem(
        IHost.DataReaderItem itemIndex,
        bytes memory input,
        uint16 version
    ) external view returns (bytes memory) {
        if (itemIndex == IHost.DataReaderItem.DAO_DATA_0) {
            (string memory symbol) = abi.decode(input, (string));
            IDAOData.DaoData memory daoData = getDAO(symbol);
            return HostEncodingLib.encodeDAOData(daoData, version);
        } else if (itemIndex == IHost.DataReaderItem.PROPOSAL_1) {
            (bytes32 proposalId) = abi.decode(input, (bytes32));
            ITokenomics.Proposal memory proposalData = proposal(proposalId);
            return HostEncodingLib.encodeProposal(proposalData, version);
        } else if (itemIndex == IHost.DataReaderItem.DAO_NAME_2) {
            HostLib.HostStorage storage $ = HostLib.getHostStorage();
            (uint daoUid, uint namingTokenKind) = abi.decode(input, (uint, uint));
            return abi.encode(getTokenName($.segment2[daoUid].name, namingTokenKind));
        } else if (itemIndex == IHost.DataReaderItem.DAO_SYMBOL_3) {
            HostLib.HostStorage storage $ = HostLib.getHostStorage();
            (uint daoUid, uint namingTokenKind) = abi.decode(input, (uint, uint));
            return abi.encode(getTokenSymbol($.segment2[daoUid].symbol, namingTokenKind));
        }
        return "";
    }

    /// @notice Get full on-chain DAO data by its symbol.
    function getDAO(string memory symbol) public view returns (IDAOData.DaoData memory dest) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        dest.uid = HostLib.getDaoUid($, symbol);

        HostLib.DaoDataSegment2 memory segment2 = $.segment2[dest.uid];
        HostLib.DaoDataSegment3 memory segment3 = $.segment3[dest.uid];

        { // ------------------- basic fields

            dest.symbol = segment2.symbol;
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
            dest.chainSettings = $.chainSettings[dest.uid];
        }

        // ------------------- units
        dest.unitIds = segment2.unitIds;
        dest.units = new IDAOData.UnitData[](segment2.unitIds.length);
        for (uint i; i < dest.units.length; i++) {
            HostLib.UnitLocal storage unit = $.units[HostLib.getUnitKey(dest.uid, segment2.unitIds[i])];
            dest.units[i].unitId = unit.unitId;
            dest.units[i].developerUid = unit.developerUid;
            dest.units[i].chainIds = unit.chainIds.values();
        }

        { // ------------------- tokenomics
            dest.initialChain = segment3.initialChain;

            dest.funding = new ITokenomics.Funding[](segment3.funding.length);
            for (uint i; i < dest.funding.length; i++) {
                dest.funding[i] = $.funding[HostLib.getKey(dest.uid, uint(segment3.funding[i]))];
            }

            dest.vesting = new ITokenomics.Vesting[](segment3.countVesting);
            dest.vestingContracts = new address[](dest.vesting.length);
            for (uint i; i < dest.vesting.length; i++) {
                dest.vesting[i] = $.vesting[HostLib.getIndexKey(dest.uid, i)];
                dest.vestingContracts[i] = address(0); // todo
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
    function getDAOOwner(string calldata symbol) external view returns (address) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);
        require(daoUid != 0, IHost.IncorrectDao());

        ITokenomics.LifecyclePhase phase = $.segment2[daoUid].phase;
        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            return $.segment3[daoUid].deployer;
        }

        if (
            phase == ITokenomics.LifecyclePhase.SEED_2 || phase == ITokenomics.LifecyclePhase.DEVELOPMENT_4
                || phase == ITokenomics.LifecyclePhase.TGE_5
        ) {
            return $.deployments[daoUid].seedToken;
        }

        return $.deployments[daoUid].daoToken;
    }

    function isDaoSymbolInUse(string calldata symbol) external view returns (bool) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        return $.daoUids[symbol] != 0;
    }

    function proposal(bytes32 proposalId) public view returns (ITokenomics.Proposal memory) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.ProposalData memory local = $.proposals[proposalId];
        HostLib.ProposalHeader memory header = HostLib.unpackProposalHeader(local.proposalHeader);
        return ITokenomics.Proposal({
            action: header.action,
            id: proposalId,
            symbol: $.segment2[local.daoUid].symbol,
            created: header.created,
            status: header.status,
            payloadHash: local.payloadHash,
            validationRequired: header.validationRequired,
            votingRequired: header.votingRequired,
            validationStatus: header.validationStatus
        });
    }

    function proposalsLength(string calldata symbol) external view returns (uint) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        return $.daoProposals[HostLib.getDaoUid($, symbol)].length;
    }

    function proposalIds(string calldata symbol, uint index, uint count) external view returns (bytes32[] memory dest) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);
        uint len = $.daoProposals[HostLib.getDaoUid($, symbol)].length;
        uint size = index + count > len ? index > len ? 0 : len - index : count;
        dest = new bytes32[](size);
        for (uint i = 0; i < size; i++) {
            dest[i] = $.daoProposals[daoUid][index + i];
        }
    }

    /// @notice Get list of pending tasks for the given DAO
    /// @param symbol DAO symbol
    /// @param limit Maximum number of tasks to return. It must be > 0. Use 1 to check if there are any tasks.
    /// @return __tasks List of tasks. The list is limited by {limit} value
    function tasks(string calldata symbol, uint limit) external view returns (IHost.Task[] memory __tasks) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        return _tasks(uint16(limit), HostLib.getDaoUid($, symbol));
    }

    /// @notice Generate token name in same way as getTokensNaming()
    /// @param name dao name
    /// @param namingTokenKind Token kind, see NamingTokenKind: 0 - seed, 1 - tge, 2 - main token, 3 - x-token, 4 - dao token
    function getTokenName(string memory name, uint namingTokenKind) internal pure returns (string memory) {
        if (namingTokenKind == uint(IHost.NamingTokenKind.SEED_0)) {
            return string(abi.encodePacked(name, " SEED"));
        } else if (namingTokenKind == uint(IHost.NamingTokenKind.TGE_1)) {
            return string(abi.encodePacked(name, " PRESALE"));
        } else if (namingTokenKind == uint(IHost.NamingTokenKind.TOKEN_2)) {
            return name;
        } else if (namingTokenKind == uint(IHost.NamingTokenKind.XTOKEN_3)) {
            return string(abi.encodePacked("x", name));
        } else if (namingTokenKind == uint(IHost.NamingTokenKind.DAO_4)) {
            return string(abi.encodePacked(name, " DAO"));
        }
        return "";
    }

    /// @notice Generate token symbol in same way as getTokensNaming()
    /// @param symbol dao symbol
    /// @param namingTokenKind Token kind, see NamingTokenKind: 0 - seed, 1 - tge, 2 - main token, 3 - x-token, 4 - dao token
    function getTokenSymbol(string memory symbol, uint namingTokenKind) internal pure returns (string memory) {
        if (namingTokenKind == uint(IHost.NamingTokenKind.SEED_0)) {
            return string(abi.encodePacked("seed", symbol));
        } else if (namingTokenKind == uint(IHost.NamingTokenKind.TGE_1)) {
            return string(abi.encodePacked("sale", symbol));
        } else if (namingTokenKind == uint(IHost.NamingTokenKind.TOKEN_2)) {
            return symbol;
        } else if (namingTokenKind == uint(IHost.NamingTokenKind.XTOKEN_3)) {
            return string(abi.encodePacked("x", symbol));
        } else if (namingTokenKind == uint(IHost.NamingTokenKind.DAO_4)) {
            return string(abi.encodePacked(symbol, "_DAO"));
        }
        return "";
    }

    /// @notice Get balance of the given unit for the given DAO
    function unitBalance(string calldata symbol, string calldata unitId) external view returns (uint) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);
        return $.unitBalances[HostLib.getUnitKey(daoUid, unitId)];
    }

    function salt(string calldata symbol, uint16 contractIndex) external view returns (bytes32) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);
        return $.salt[HostLib.getKey(daoUid, contractIndex)];
    }

    function getBridgedAction(bytes32 actionHash) external view returns (bool applied, uint16 actionKind, uint daoUid) {
        HostLib.BridgedActionLocal storage local = HostLib.getHostStorage().bridgedActionHashes[actionHash];
        HostLib.BridgedActionHeader memory header = HostLib.unpackBridgedActionHeader(local.bridgedActionHeader);
        return (header.applied, header.actionKind, local.daoUid);
    }
    //endregion -------------------------------------- View

    //region -------------------------------------- Internal utils

    function _tasks(uint16 limit, uint daoUid) internal view returns (IHost.Task[] memory dest) {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        dest = new IHost.Task[](limit);

        // slither-disable-next-line uninitialized-local
        uint index;

        ITokenomics.LifecyclePhase phase = $.segment2[daoUid].phase;

        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            index = _tasksDraft($, daoUid, dest);
        } else if (phase == ITokenomics.LifecyclePhase.INCEPTION_1) {
            index = _tasksInception($, daoUid, dest);
        } else if (phase == ITokenomics.LifecyclePhase.SEED_2) {
            index = _tasksSeed($, daoUid, dest);
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_4) {
            index = _tasksDevelopment($, daoUid, dest);
        } else if (phase == ITokenomics.LifecyclePhase.TGE_5) {
            index = _tasksTge($, daoUid, dest);
        } else if (phase == ITokenomics.LifecyclePhase.LIVE_CLIFF_6) {
            index = _tasksLiveCliff($, daoUid, dest);
        } else if (phase == ITokenomics.LifecyclePhase.LIVE_VESTING_7) {
            index = _tasksLiveVesting($, daoUid, dest);
        } else if (phase == ITokenomics.LifecyclePhase.LIVE_8) {
            index = _tasksLive($, daoUid, dest);
        }

        // trim array
        if (index < dest.length) {
            IHost.Task[] memory temp = new IHost.Task[](index);
            for (uint i; i < index; ++i) {
                temp[i] = dest[i];
            }
            dest = temp;
        }

        return dest;
    }

    /// @dev Check tasks for DRAFT phase. Return number of filled tasks in dest array
    function _tasksDraft(
        HostLib.HostStorage storage $,
        uint daoUid,
        IHost.Task[] memory dest
    ) internal view returns (uint) {
        ITokenomics.DaoImages memory daoImages = $.daoImages[daoUid];

        uint limit = dest.length;
        // slither-disable-next-line uninitialized-local
        uint index;

        if (index < limit && (bytes(daoImages.seedToken).length == 0 || bytes(daoImages.token).length == 0)) {
            dest[index++] = IHost.Task("Need images of token and seedToken");
        }
        if (index < limit && $.segment3[daoUid].socials.length < 2) {
            dest[index++] = IHost.Task("Need at least 2 socials");
        }
        if (index < limit && $.segment2[daoUid].unitIds.length == 0) {
            dest[index++] = IHost.Task("Need at least 1 projected unit");
        }

        return index;
    }

    /// @dev Check tasks for INCEPTION phase. Return number of filled tasks in dest array
    function _tasksInception(
        HostLib.HostStorage storage /*$*/,
        uint /*daoUid*/,
        IHost.Task[] memory /*dest*/
    ) internal pure returns (uint) {

        // there are no on-chain tasks

        return 0;
    }

    function _tasksSeed(
        HostLib.HostStorage storage $,
        uint daoUid,
        IHost.Task[] memory dest
    ) internal view returns (uint) {
        uint limit = dest.length;

        // slither-disable-next-line uninitialized-local
        uint index;

        ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];

        if (index < limit && seed.raised < seed.minRaise && seed.end > block.timestamp) {
            dest[index++] = IHost.Task("Need attract minimal seed funding");
        }

        return index;
    }

    function _tasksDevelopment(
        HostLib.HostStorage storage $,
        uint daoUid,
        IHost.Task[] memory dest
    ) internal view returns (uint) {
        uint limit = dest.length;

        // slither-disable-next-line uninitialized-local
        uint index;

        ITokenomics.Funding memory tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

        if (index < limit && tge.fundingType != ITokenomics.FundingType.TGE_1) {
            dest[index++] = IHost.Task("Need add pre-TGE funding");
        }

        ITokenomics.DaoImages memory daoImages = $.daoImages[daoUid];

        if (
            index < limit
                && (bytes(daoImages.tgeToken).length == 0
                    || bytes(daoImages.xToken).length == 0
                    || bytes(daoImages.daoToken).length == 0)
        ) {
            dest[index++] = IHost.Task("Need images of all DAO tokens");
        }

        if (index < limit && $.segment3[daoUid].countVesting == 0) {
            dest[index++] = IHost.Task("Need vesting allocations");
        }

        string[] memory unitIds = $.segment2[daoUid].unitIds;

        // slither-disable-next-line uninitialized-local
        bool foundLive;

        // assume that a unit is live if it has received not zero income
        for (uint i; i < unitIds.length; i++) {
            // todo do we need to use a threshold here?
            if ($.unitBalances[HostLib.getUnitKey(daoUid, unitIds[i])] != 0) {
                foundLive = true;
                break;
            }
        }

        if (index < limit && !foundLive) {
            dest[index++] = IHost.Task("Run revenue generating units");
        }

        return index;
    }

    function _tasksTge(
        HostLib.HostStorage storage $,
        uint daoUid,
        IHost.Task[] memory dest
    ) internal view returns (uint) {
        uint limit = dest.length;

        // slither-disable-next-line uninitialized-local
        uint index;

        ITokenomics.Funding memory f = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

        if (index < limit && f.raised < f.minRaise && f.end > block.timestamp) {
            dest[index++] = IHost.Task("Need attract minimal TGE funding");
        }

        return index;
    }

    function _tasksLiveCliff(HostLib.HostStorage storage, uint, IHost.Task[] memory) internal pure returns (uint) {
        // establish and improve
        // build money markets
        // bridge to chains
        return 0;
    }

    function _tasksLiveVesting(HostLib.HostStorage storage, uint, IHost.Task[] memory) internal pure returns (uint) {
        // distribute vesting funds to leverage token
        return 0;
    }

    function _tasksLive(HostLib.HostStorage storage, uint, IHost.Task[] memory) internal pure returns (uint) {
        // lifetime revenue generating for DAO holders till possible absorbing
        return 0;
    }

    //endregion -------------------------------------- Internal utils
}
