// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {HostViewLib} from "../../src/libs/HostViewLib.sol";
import {HostLib} from "../../src/libs/HostLib.sol";

contract HostViewLibTest is Test {
    function testGetTokenName() public pure {
        string memory name = "abc";
        assertEq(HostViewLib.getTokenName(name, uint(IHost.NamingTokenKind.SEED_0)), "abc SEED");
        assertEq(HostViewLib.getTokenName(name, uint(IHost.NamingTokenKind.TGE_1)), "abc PRESALE");
        assertEq(HostViewLib.getTokenName(name, uint(IHost.NamingTokenKind.TOKEN_2)), "abc");
        assertEq(HostViewLib.getTokenName(name, uint(IHost.NamingTokenKind.XTOKEN_3)), "xabc");
        assertEq(HostViewLib.getTokenName(name, uint(IHost.NamingTokenKind.DAO_4)), "abc DAO");
    }

    function testGetTokenSymbol() public pure {
        string memory name = "ABC";
        assertEq(HostViewLib.getTokenSymbol(name, uint(IHost.NamingTokenKind.SEED_0)), "seedABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(IHost.NamingTokenKind.TGE_1)), "saleABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(IHost.NamingTokenKind.TOKEN_2)), "ABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(IHost.NamingTokenKind.XTOKEN_3)), "xABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(IHost.NamingTokenKind.DAO_4)), "ABC_DAO");
    }

    //region ----------------------------------- _tasksDraft
    function testTasksDraft_MinRequiredData_ReturnEmptyArray() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
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

        ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
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

        ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
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

        ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
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

        ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
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

    //region ----------------------------------- _tasksSeed
    function testTasksSeed_MinRequiredData_ReturnEmptyArray() public view {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
        seed.fundingType = ITokenomics.FundingType.SEED_0;
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

        ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
        seed.fundingType = ITokenomics.FundingType.SEED_0;
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

        ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
        seed.fundingType = ITokenomics.FundingType.SEED_0;
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

        ITokenomics.Funding storage seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
        seed.fundingType = ITokenomics.FundingType.SEED_0;
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

        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
        tge.fundingType = ITokenomics.FundingType.TGE_1;

        ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.tgeToken = "a";
        daoImages.xToken = "a";
        daoImages.daoToken = "a";

        $.segment3[daoUid].countVesting = 1;
        $.segment2[daoUid].unitIds = new string[](2);
        $.segment2[daoUid].unitIds[0] = "unit1";
        $.segment2[daoUid].unitIds[1] = "unit2";

        $.unitBalances[HostLib.getUnitKey(daoUid, "unit2")] = 1; // only single unit has not zero balance

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
        assertEq(countItems, 0, "no tasks");
    }

    function testTasksDevelopment_NoTge_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.tgeToken = "a";
        daoImages.xToken = "a";
        daoImages.daoToken = "a";

        $.segment3[daoUid].countVesting = 1;
        $.segment2[daoUid].unitIds = new string[](1);
        $.segment2[daoUid].unitIds[0] = "unit1";

        $.unitBalances[HostLib.getUnitKey(daoUid, "unit1")] = 1;

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Need add pre-TGE funding", "Need add pre-TGE funding");
    }

    function testTasksDevelopment_NoImage_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
        tge.fundingType = ITokenomics.FundingType.TGE_1;

        $.segment3[daoUid].countVesting = 1;
        $.segment2[daoUid].unitIds = new string[](1);
        $.segment2[daoUid].unitIds[0] = "unit1";
        $.unitBalances[HostLib.getUnitKey(daoUid, "unit1")] = 1;

        IHost.Task[] memory dest = new IHost.Task[](25);
        for (uint i; i < 3; ++i) {
            ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
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

        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
        tge.fundingType = ITokenomics.FundingType.TGE_1;

        ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.tgeToken = "a";
        daoImages.xToken = "a";
        daoImages.daoToken = "a";

        $.segment2[daoUid].unitIds = new string[](1);
        $.segment2[daoUid].unitIds[0] = "unit1";

        $.unitBalances[HostLib.getUnitKey(daoUid, "unit1")] = 1;

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Need vesting allocations", "Need vesting allocations");
    }

    function testTasksDevelopment_UnitHasZeroBalance_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
        tge.fundingType = ITokenomics.FundingType.TGE_1;

        ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.tgeToken = "a";
        daoImages.xToken = "a";
        daoImages.daoToken = "a";

        $.segment3[daoUid].countVesting = 1;
        $.segment2[daoUid].unitIds = new string[](1);
        $.segment2[daoUid].unitIds[0] = "unit1";

        // $.unitBalances[HostLib.getUnitKey(daoUid, "unit1")] = 1;

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Run revenue generating units", "Run revenue generating units");
    }

    function testTasksDevelopment_NoUnits_Return1() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
        tge.fundingType = ITokenomics.FundingType.TGE_1;

        ITokenomics.DaoImages storage daoImages = $.daoImages[daoUid];
        daoImages.tgeToken = "a";
        daoImages.xToken = "a";
        daoImages.daoToken = "a";

        $.segment3[daoUid].countVesting = 1;

        IHost.Task[] memory dest = new IHost.Task[](25);
        uint countItems = HostViewLib._tasksDevelopment($, daoUid, dest);
        assertEq(countItems, 1, "1 task");
        assertEq(dest[0].name, "Run revenue generating units", "Run revenue generating units");
    }
    //endregion ----------------------------------- _tasksDevelopment

    //region ----------------------------------- _tasksTge
    function testTasksTge_MinRequiredData_ReturnEmptyArray() public view {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
        seed.fundingType = ITokenomics.FundingType.TGE_1;
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

        ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
        seed.fundingType = ITokenomics.FundingType.TGE_1;
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

        ITokenomics.Funding memory seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
        seed.fundingType = ITokenomics.FundingType.TGE_1;
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

        ITokenomics.Funding storage seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];
        seed.fundingType = ITokenomics.FundingType.TGE_1;
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
