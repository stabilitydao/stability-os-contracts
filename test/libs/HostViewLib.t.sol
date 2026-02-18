// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Test} from "forge-std/Test.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";
import {HostViewLib} from "../../src/libs/HostViewLib.sol";
import {HostLib} from "../../src/libs/HostLib.sol";
import {HostConfigLib} from "../../src/libs/HostConfigLib.sol";

contract HostViewLibTest is Test {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    //region ----------------------------------- Settings and ChainSettings
    function testWriteReadSettings_MaxValues_ReadSameValues() public {
        HostConfigLib.HostGlobalStorage storage $ = HostConfigLib.getHostGlobalStorage();
        IHost.HostSettings memory src = IHost.HostSettings({
            priceDao: type(uint).max,
            fundingFee: type(uint).max,
            minNameLength: type(uint16).max,
            maxNameLength: type(uint16).max,
            minSymbolLength: type(uint16).max,
            maxSymbolLength: type(uint16).max,
            minVePeriod: type(uint24).max,
            maxVePeriod: type(uint24).max,
            minPvPFee: type(uint).max,
            maxPvPFee: type(uint).max,
            minFunding: type(uint).max,
            minFundingDuration: type(uint64).max,
            maxFundingDuration: type(uint64).max,
            minFundingRaise: type(uint).max,
            maxFundingRaise: type(uint).max,
            minVestingNameLen: type(uint16).max,
            maxVestingNameLen: type(uint16).max,
            minCliff: type(uint64).max,
            minInceptionDuration: type(uint64).max
        });
        $.globalSettings = src;
        IHost.HostSettings memory read = HostViewLib.getSettings();
        assertEq(keccak256(abi.encode(read)), keccak256(abi.encode(src)), "read data is same to written data");
    }

    function testWriteReadSettings_TypicalValues_ReadSameValues() public {
        HostConfigLib.HostGlobalStorage storage $ = HostConfigLib.getHostGlobalStorage();
        IHost.HostSettings memory src = IHost.HostSettings({
            priceDao: 1000e27,
            fundingFee: 1001e27,
            minNameLength: 20000,
            maxNameLength: 20001,
            minSymbolLength: 20002,
            maxSymbolLength: 20003,
            minVePeriod: 100_000,
            maxVePeriod: 100_000 * 4,
            minPvPFee: 1002e27,
            maxPvPFee: 1003e27,
            minFunding: 1004e27,
            minFundingDuration: 100_001 days,
            maxFundingDuration: 100_002 days,
            minFundingRaise: 1003e27,
            maxFundingRaise: 1004e27,
            minVestingNameLen: 20004,
            maxVestingNameLen: 20005,
            minCliff: 100_003 days,
            minInceptionDuration: 100_004 days
        });
        $.globalSettings = src;
        IHost.HostSettings memory read = HostViewLib.getSettings();
        assertEq(keccak256(abi.encode(read)), keccak256(abi.encode(src)), "read data is same to written data");
    }

    function testWriteReadChainSettings_TypicalValues_ReadSameValues() public {
        HostConfigLib.HostChainStorage storage $ = HostConfigLib.getHostChainStorage();
        IHost.HostChainSettings memory src = IHost.HostChainSettings({
            exchangeAsset: makeAddr("asset"),
            hostBridge: makeAddr("host"),
            timelock: 100_000 days,
            dataReader: makeAddr("reader")
        });
        $.chainSettings = src;
        IHost.HostChainSettings memory read = HostViewLib.getChainSettings();
        assertEq(keccak256(abi.encode(read)), keccak256(abi.encode(src)), "read data is same to written data");
    }

    //endregion ----------------------------------- Settings and ChainSettings

    //region ----------------------------------- getDAOOwner

    /// @dev All phases where segment3.developer is owner
    function fixturePhaseDeployer() public pure returns (IDAOData.LifecyclePhase[] memory phases) {
        phases = new IDAOData.LifecyclePhase[](3);
        phases[0] = IDAOData.LifecyclePhase.DRAFT_0;
        phases[1] = IDAOData.LifecyclePhase.INCEPTION_1;
        phases[2] = IDAOData.LifecyclePhase.SEED_FAILED_3;
    }

    function tableGetDAOOwner_PhaseDeployer_ReturnSegment3Deployer(IDAOData.LifecyclePhase phaseDeployer) public {
        uint daoUid = 97;
        address owner = makeAddr("owner");

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment3[daoUid].deployer = owner;

        $.segment2[daoUid].phase = phaseDeployer;
        $.segment2[daoUid].symbol = "a";
        $.daoUids["a"] = daoUid;

        assertEq(HostViewLib.getDAOOwner("a"), owner, "owner is segment3.developer");
    }

    /// @dev All phases where seed token is owner
    function fixturePhaseSeed() public pure returns (IDAOData.LifecyclePhase[] memory phases) {
        phases = new IDAOData.LifecyclePhase[](3);
        phases[0] = IDAOData.LifecyclePhase.SEED_2;
        phases[1] = IDAOData.LifecyclePhase.DEVELOPMENT_4;
        phases[2] = IDAOData.LifecyclePhase.TGE_5;
    }

    function tableGetDAOOwner_PhaseSeed_ReturnSeedToken(IDAOData.LifecyclePhase phaseSeed) public {
        uint daoUid = 97;
        address owner = makeAddr("owner");

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.deployments[daoUid].seedToken = owner;

        $.segment2[daoUid].phase = phaseSeed;
        $.segment2[daoUid].symbol = "a";
        $.daoUids["a"] = daoUid;

        assertEq(HostViewLib.getDAOOwner("a"), owner, "owner is seed token");
    }

    /// @dev All phases where DAO token is owner
    function fixturePhaseDao() public pure returns (IDAOData.LifecyclePhase[] memory phases) {
        phases = new IDAOData.LifecyclePhase[](3);
        phases[0] = IDAOData.LifecyclePhase.LIVE_CLIFF_6;
        phases[1] = IDAOData.LifecyclePhase.LIVE_VESTING_7;
        phases[2] = IDAOData.LifecyclePhase.LIVE_8;
    }

    function tableGetDAOOwner_PhaseDao_ReturnDaoToken(IDAOData.LifecyclePhase phaseDao) public {
        uint daoUid = 97;
        address owner = makeAddr("owner");

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.deployments[daoUid].daoToken = owner;

        $.segment2[daoUid].phase = phaseDao;
        $.segment2[daoUid].symbol = "a";
        $.daoUids["a"] = daoUid;

        assertEq(HostViewLib.getDAOOwner("a"), owner, "owner is TGE token");
    }

    //endregion ----------------------------------- getDAOOwner

    //region ----------------------------------- getTokenName, getTokenSymbol
    function testGetTokenName() public pure {
        string memory name = "abc";
        assertEq(HostViewLib.getTokenName(name, uint(IHost.NamingTokenKind.SEED_0)), "abc SEED");
        assertEq(HostViewLib.getTokenName(name, uint(IHost.NamingTokenKind.TGE_1)), "abc PRESALE");
        assertEq(HostViewLib.getTokenName(name, uint(IHost.NamingTokenKind.TOKEN_2)), "abc");
        assertEq(HostViewLib.getTokenName(name, uint(IHost.NamingTokenKind.XTOKEN_3)), "xabc");
        assertEq(HostViewLib.getTokenName(name, uint(IHost.NamingTokenKind.DAO_4)), "abc DAO");
        assertEq(HostViewLib.getTokenName(name, 255), "", "unknown kind");
    }

    function testGetTokenSymbol() public pure {
        string memory name = "ABC";
        assertEq(HostViewLib.getTokenSymbol(name, uint(IHost.NamingTokenKind.SEED_0)), "seedABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(IHost.NamingTokenKind.TGE_1)), "saleABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(IHost.NamingTokenKind.TOKEN_2)), "ABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(IHost.NamingTokenKind.XTOKEN_3)), "xABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(IHost.NamingTokenKind.DAO_4)), "ABC_DAO");
        assertEq(HostViewLib.getTokenName(name, 255), "", "unknown kind");
    }

    //endregion ----------------------------------- getTokenName, getTokenSymbol

    //region ----------------------------------- _tasksDraft
    function testTasksDraft_MinRequiredData_ReturnEmptyArray() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.seedToken = "a";
        daoImages.token = "a";

        $.segment3[daoUid].socials = new string[](2);
        $.segment2[daoUid].unitIds = new string[](1);

        for (uint limit = 1; limit < 3; ++limit) {
            IHost.Task[] memory dest = new IHost.Task[](limit);
            uint countItems = HostViewLib._tasksDraft($, daoUid, dest);
            assertEq(countItems, 0, "no tasks");
        }
    }

    function testTasksDraft_NoTokenImage_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.seedToken = "a";
        daoImages.token = ""; // (!)

        $.segment3[daoUid].socials = new string[](2);
        $.segment2[daoUid].unitIds = new string[](1);

        for (uint limit = 1; limit < 3; ++limit) {
            IHost.Task[] memory dest = new IHost.Task[](limit);
            uint countItems = HostViewLib._tasksDraft($, daoUid, dest);
            assertEq(countItems, 1, "1 task");
            assertEq(dest[0].name, "Need images of token and seedToken", "Need images of token");
        }
    }

    function testTasksDraft_NoSeedTokenImage_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.seedToken = ""; // (!)
        daoImages.token = "a";

        $.segment3[daoUid].socials = new string[](2);
        $.segment2[daoUid].unitIds = new string[](1);

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDraft($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Need images of token and seedToken", "Need images of token");
    }

    function testTasksDraft_SingleSocial_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.seedToken = "a";
        daoImages.token = "a";

        $.segment3[daoUid].socials = new string[](1); // (!)
        $.segment2[daoUid].unitIds = new string[](1);

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDraft($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Need at least 2 socials", "Need at least 2 socials");
    }

    function testTasksDraft_NoUnits_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.seedToken = "a";
        daoImages.token = "a";

        $.segment3[daoUid].socials = new string[](2);
        $.segment2[daoUid].unitIds = new string[](0); // (!)

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDraft($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Need at least 1 projected unit", "Need at least 1 projected unit");
    }

    function testTasksDraft_EmptyDataLimit25_Return3() public view {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDraft($, daoUid, dest);
        assertEq(countItems, 3, "3 tasks");
        assertEq(dest[0].name, "Need images of token and seedToken", "Need images of token and seedToken");
        assertEq(dest[1].name, "Need at least 2 socials", "Need at least 2 socials");
        assertEq(dest[2].name, "Need at least 1 projected unit", "Need at least 1 projected unit");
    }

    function testTasksDraft_EmptyDataLimited_Return1() public view {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        for (uint limit = 1; limit < 4; ++limit) {
            IHost.Task[] memory dest = new IHost.Task[](limit);
            uint countItems = HostViewLib._tasksDraft($, daoUid, dest);
            assertEq(countItems, limit, "Number of tasks is equal to limit");
        }
    }

    //endregion ----------------------------------- _tasksDraft

    //region ----------------------------------- _tasksInception
    function testTasksDraft_AnyInputData_ReturnEmptyArray() public pure {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksInception($, daoUid, dest);
        assertEq(countItems, 0, "no tasks");
    }

    //endregion ----------------------------------- _tasksInception

    //region ----------------------------------- _tasksSeed
    function testTasksSeed_MinRequiredData_ReturnEmptyArray() public view {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.SEED_0))];
        seed.fundingType = IDAOData.FundingType.SEED_0;
        seed.raised = 100;
        seed.minRaise = 100;
        seed.end = uint64(block.timestamp);

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksSeed($, daoUid, dest);
        assertEq(countItems, 0, "no tasks");
    }

    function testTasksSeed_RaisedNotEnoughNotEnded_ReturnEmptyArray() public view {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.SEED_0))];
        seed.fundingType = IDAOData.FundingType.SEED_0;
        seed.raised = 99; // (!)
        seed.minRaise = 100;
        seed.end = uint64(block.timestamp);

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksSeed($, daoUid, dest);
        assertEq(countItems, 0, "0 tasks");
    }

    function testTasksSeed_RaisedReachedEnded_ReturnEmptyArray() public view {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.SEED_0))];
        seed.fundingType = IDAOData.FundingType.SEED_0;
        seed.raised = 101;
        seed.minRaise = 100;
        seed.end = uint64(block.timestamp) + 1; // (!)

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksSeed($, daoUid, dest);
        assertEq(countItems, 0, "0 tasks");
    }

    function testTasksSeed_AllWrongLimit1_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding storage seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.SEED_0))];
        seed.fundingType = IDAOData.FundingType.SEED_0;
        seed.raised = 0; // (!)
        seed.minRaise = 100;
        seed.end = uint64(block.timestamp) + 1; // (!)

        IHost.Task[] memory dest = new IHost.Task[](1);
        uint countItems = HostViewLib._tasksSeed($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Need attract minimal seed funding", "Need attract minimal seed funding");
    }

    //endregion ----------------------------------- _tasksSeed

    //region ----------------------------------- _tasksDevelopment
    function testTasksDevelopment_MinRequiredData_ReturnEmptyArray() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.TGE_1))];
        tge.fundingType = IDAOData.FundingType.TGE_1;

        IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.tgeToken = "a";
        daoImages.xToken = "a";
        daoImages.daoToken = "a";

        $.segment3[daoUid].countVesting = 1;
        $.segment2[daoUid].unitIds = new string[](2);
        $.segment2[daoUid].unitIds[0] = "unit1";
        $.segment2[daoUid].unitIds[1] = "unit2";

        $.unitBalances[HostLib.getUnitKey(daoUid, "unit2")].set(makeAddr("exchangeAsset"), 1); // only single unit has not zero balance

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
        assertEq(countItems, 0, "no tasks");
    }

    function testTasksDevelopment_NoTge_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.tgeToken = "a";
        daoImages.xToken = "a";
        daoImages.daoToken = "a";

        $.segment3[daoUid].countVesting = 1;
        $.segment2[daoUid].unitIds = new string[](1);
        $.segment2[daoUid].unitIds[0] = "unit1";

        $.unitBalances[HostLib.getUnitKey(daoUid, "unit1")].set(makeAddr("exchangeAsset"), 1);

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Need add pre-TGE funding", "Need add pre-TGE funding");
    }

    function testTasksDevelopment_NoImage_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.TGE_1))];
        tge.fundingType = IDAOData.FundingType.TGE_1;

        $.segment3[daoUid].countVesting = 1;
        $.segment2[daoUid].unitIds = new string[](1);
        $.segment2[daoUid].unitIds[0] = "unit1";
        $.unitBalances[HostLib.getUnitKey(daoUid, "unit1")].set(makeAddr("exchangeAsset"), 1);

        IHost.Task[] memory dest = new IHost.Task[](25);
        for (uint i; i < 3; ++i) {
            IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
            daoImages.tgeToken = i == 0 ? "" : "a";
            daoImages.xToken = i == 1 ? "" : "a";
            daoImages.daoToken = i == 2 ? "" : "a";

            uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
            assertEq(countItems, 1, "1 task");
            assertEq(dest[0].name, "Need images of all DAO tokens", "Need images of all DAO tokens");
        }
    }

    function testTasksDevelopment_NoVesting_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.TGE_1))];
        tge.fundingType = IDAOData.FundingType.TGE_1;

        IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.tgeToken = "a";
        daoImages.xToken = "a";
        daoImages.daoToken = "a";

        $.segment2[daoUid].unitIds = new string[](1);
        $.segment2[daoUid].unitIds[0] = "unit1";

        $.unitBalances[HostLib.getUnitKey(daoUid, "unit1")].set(makeAddr("exchangeAsset"), 1);

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Need vesting allocations", "Need vesting allocations");
    }

    function testTasksDevelopment_UnitHasZeroBalance_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.TGE_1))];
        tge.fundingType = IDAOData.FundingType.TGE_1;

        IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.tgeToken = "a";
        daoImages.xToken = "a";
        daoImages.daoToken = "a";

        $.segment3[daoUid].countVesting = 1;
        $.segment2[daoUid].unitIds = new string[](1);
        $.segment2[daoUid].unitIds[0] = "unit1";

        // $.unitBalances[HostLib.getUnitKey(daoUid, "unit1")].set(makeAddr("exchangeAsset"), 1);

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Start generate revenue", "Start generate revenue");
    }

    function testTasksDevelopment_NoUnits_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.TGE_1))];
        tge.fundingType = IDAOData.FundingType.TGE_1;

        IDAOData.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.tgeToken = "a";
        daoImages.xToken = "a";
        daoImages.daoToken = "a";

        $.segment3[daoUid].countVesting = 1;

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Start generate revenue", "Start generate revenue");
    }

    //endregion ----------------------------------- _tasksDevelopment

    //region ----------------------------------- _tasksTge
    function testTasksTge_MinRequiredData_ReturnEmptyArray() public view {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.SEED_0))];
        seed.fundingType = IDAOData.FundingType.TGE_1;
        seed.raised = 100;
        seed.minRaise = 100;
        seed.end = uint64(block.timestamp);

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksTge($, daoUid, dest);
        assertEq(countItems, 0, "no tasks");
    }

    function testTasksTge_RaisedNotEnoughNotEnded_ReturnEmptyArray() public view {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.TGE_1))];
        seed.fundingType = IDAOData.FundingType.TGE_1;
        seed.raised = 99; // (!)
        seed.minRaise = 100;
        seed.end = uint64(block.timestamp);

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksTge($, daoUid, dest);
        assertEq(countItems, 0, "0 tasks");
    }

    function testTasksTge_RaisedReachedEnded_ReturnEmptyArray() public view {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.TGE_1))];
        seed.fundingType = IDAOData.FundingType.TGE_1;
        seed.raised = 101;
        seed.minRaise = 100;
        seed.end = uint64(block.timestamp) + 1; // (!)

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksTge($, daoUid, dest);
        assertEq(countItems, 0, "0 tasks");
    }

    function testTasksTge_AllWrongLimit1_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        IDAOData.Funding storage seed = $.funding[HostLib.getKey(daoUid, uint(IDAOData.FundingType.TGE_1))];
        seed.fundingType = IDAOData.FundingType.TGE_1;
        seed.raised = 0; // (!)
        seed.minRaise = 100;
        seed.end = uint64(block.timestamp) + 1; // (!)

        IHost.Task[] memory dest = new IHost.Task[](1);
        uint countItems = HostViewLib._tasksTge($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Need attract minimal TGE funding", "Need attract minimal TGE funding");
    }
    //endregion ----------------------------------- _tasksTge
}
