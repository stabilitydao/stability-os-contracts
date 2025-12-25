// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDAOUnit, ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {IOS} from "../../src/os/OS.sol";
import {OsUtilsLib} from "./utils/OsUtilsLib.sol";
import {Test} from "forge-std/Test.sol";
// import {console} from "forge-std/console.sol";

contract OsLifeCycleTest is Test, OsUtilsLib {
    address internal immutable MULTISIG;
    address internal constant FIRST_SEEDER = address(0x11);
    address internal constant SECOND_SEEDER = address(0x22);
    address internal constant THIRD_SEEDER = address(0x33);

    address internal usdc;

    constructor() {
        // vm.selectFork(vm.createFork(vm.envString("SONIC_RPC_URL"), FORK_BLOCK));
        MULTISIG = makeAddr("multisig");
    }

    /// @notice Test single DAO life cycle
    function testLifeCycle56() public {
        // ------------------------------ First DAO is Aliens community
        IOS os56 = OsUtilsLib.createOsInstance(vm, MULTISIG);

        lifeCycleDaoAlien56(os56);

        // ------------------------------ Second DAO
        // second DAO are APES syndicate
        // they cant build but need their own DeFi lending protocol
        // they do many errors

        // todo Second DAO should be created on chain 1 but currently it's created on chain 56
        lifeCycleDaoApes1(os56);

        // ------------------------------ Third DAO
        // third DAO are Machines Cartel
        // todo Third DAO should be created on chain 10 but currently it's created on chain 56
        lifeCycleDaoMachines10(os56);
    }

    //region ------------------------------ Life cycles logic
    function lifeCycleDaoAlien56(IOS os56) internal {
        address asset = os56.getChainSettings().exchangeAsset;

        // ------------------------------ Create DAO
        {
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
            funding[0] = OsUtilsLib.generateSeedFunding(
                DEFAULT_SEED_DELAY, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
            );

            ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](2);
            activity[0] = ITokenomics.Activity.BUILDER_3;
            activity[1] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

            ITokenomics.DaoParameters memory params = OsUtilsLib.generateDaoParams(365, 100);

            os56.createDAO("Aliens Community", "ALIENS", activity, params, funding);
        }

        // todo other OS instances must see a symbol of new DAO

        ITokenomics.DaoData memory daoData = os56.getDAO("ALIENS");

        // ------------------------------ 7 days later (draft phase)
        {
            skip(7 days);

            vm.expectRevert(IOS.SolveTasksFirst.selector);
            os56.changePhase(daoData.symbol);
        }

        // ------------------------------ check what aliens need to do
        {
            IOS.Task[] memory tasks = os56.tasks(daoData.symbol);
            assertGe(tasks.length, 2, "at least 2 unsolved tasks");

            // deployer drew token logotypes
            ITokenomics.DaoImages memory images = ITokenomics.DaoImages({
                seedToken: "/seedAliens.png", tgeToken: "", token: "/aliens.png", xToken: "", daoToken: ""
            });
            os56.updateImages(daoData.symbol, images);

            {
                IOS.Task[] memory tasksAfter = os56.tasks(daoData.symbol);
                assertLe(tasksAfter.length, tasks.length, "number of tasks should decrease");
            }

            // units project
            IDAOUnit.UnitInfo[] memory units = new IDAOUnit.UnitInfo[](1);
            units[0] = IDAOUnit.UnitInfo({
                unitId: "aliens:os",
                name: "DAO Factory",
                status: IDAOUnit.UnitStatus.BUILDING_1,
                unitType: uint16(IDAOUnit.UnitType.DEFI_PROTOCOL_1),
                revenueShare: 100,
                ui: new IDAOUnit.UnitUiLink[](0),
                emoji: "",
                api: new string[](0)
            });
            os56.updateUnits(daoData.symbol, units);

            // registered socials
            string[] memory socials = new string[](2);
            socials[0] = "https://a.aa/a";
            socials[1] = "https://b.bb/b";

            os56.updateSocials(daoData.symbol, socials);

            {
                IOS.Task[] memory tasksAfter = os56.tasks(daoData.symbol);
                assertEq(tasksAfter.length, 0, "all tasks solved");
            }
        }

        // ------------------------------ fix funding
        {
            ITokenomics.Funding memory funding = ITokenomics.Funding({
                fundingType: daoData.tokenomics.funding[0].fundingType,
                start: daoData.tokenomics.funding[0].start,
                end: daoData.tokenomics.funding[0].end,
                minRaise: daoData.tokenomics.funding[0].minRaise,
                maxRaise: 90_000e18,
                raised: daoData.tokenomics.funding[0].raised,
                claim: daoData.tokenomics.funding[0].claim
            });
            os56.updateFunding(daoData.symbol, funding);
        }

        // ------------------------------ phase cant be changed right now
        {
            vm.expectRevert(IOS.WaitFundingStart.selector);
            os56.changePhase(daoData.symbol);

            skip(24 days);
        }

        // ------------------------------ change phase to seed
        {
            os56.changePhase(daoData.symbol);
            ITokenomics.DaoData memory daoDataAfter = os56.getDAO(daoData.symbol);

            assertEq(uint8(daoDataAfter.phase), uint8(ITokenomics.LifecyclePhase.SEED_1), "phase should be SEED");

            IOS.Task[] memory tasks = os56.tasks(daoData.symbol);
            assertGt(tasks.length, 0, "at least 1 unsolved tasks");
        }

        // ------------------------------ setup seed token, refresh daoData
        {
            daoData = os56.getDAO(daoData.symbol);
            //OsUtilsLib.printDaoData(daoData);
            OsUtilsLib.setupSeedToken(vm, os56, MULTISIG, daoData.deployments.seedToken);
        }

        // ------------------------------ SEED started. First seeder
        {
            deal(asset, FIRST_SEEDER, 5000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(os56), 5000e18);

            vm.prank(FIRST_SEEDER);
            os56.fund(daoData.symbol, 1000e18);

            assertEq(IERC20(asset).balanceOf(FIRST_SEEDER), 4000e18, "first seeder balance after funding");
            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(FIRST_SEEDER),
                1000e18,
                "first seeder seed token balance after funding"
            );
        }

        // ------------------------------ since seed has funds first governance proposal can be created
        {
            string[] memory socials = new string[](3);
            socials[0] = "https://a.aa/a1";
            socials[1] = "https://b.bb/b2";
            socials[2] = "https://c.cc/c3";

            os56.updateSocials(daoData.symbol, socials);

            bytes32[] memory proposalIds = os56.proposalIds(daoData.symbol, 0, 1);
            assertEq(proposalIds.length, 1, "one proposal should be created");

            vm.prank(MULTISIG);
            os56.receiveVotingResults(proposalIds[0], true);

            ITokenomics.DaoData memory daoAfter = os56.getDAO("ALIENS");
            assertEq(daoAfter.socials.length, 3, "socials should be updated after proposal");

            assertEq(
                keccak256(abi.encode(socials)), keccak256(abi.encode(daoAfter.socials)), "socials data should match"
            );

            vm.expectRevert(IOS.AlreadyReceived.selector);
            vm.prank(MULTISIG);
            os56.receiveVotingResults(proposalIds[0], true);

            vm.expectRevert(IOS.IncorrectProposal.selector);
            vm.prank(MULTISIG);
            os56.receiveVotingResults(bytes32(uint(proposalIds[0]) + 1), true);
        }

        // ------------------------------ Second seeder
        {
            deal(asset, SECOND_SEEDER, 10000e18);

            vm.prank(SECOND_SEEDER);
            IERC20(asset).approve(address(os56), type(uint).max);

            vm.prank(SECOND_SEEDER);
            os56.fund(daoData.symbol, 10000e18);

            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(SECOND_SEEDER),
                10000e18,
                "second seeder seed token balance after funding"
            );

            deal(asset, SECOND_SEEDER, 100000000e18);

            vm.expectRevert(IOS.RaiseMaxExceed.selector);
            vm.prank(SECOND_SEEDER);
            os56.fund(daoData.symbol, 100000000e18);
        }

        // ------------------------------ phase cant be changed right now
        {
            vm.expectRevert(IOS.WaitFundingEnd.selector);
            os56.changePhase(daoData.symbol);

            skip(100 days);
        }

        // ------------------------------ DEVELOPMENT phase started (SEED succeed), refresh daoData
        {
            os56.changePhase(daoData.symbol);
            daoData = os56.getDAO(daoData.symbol);

            assertEq(
                uint8(daoData.phase), uint8(ITokenomics.LifecyclePhase.DEVELOPMENT_3), "phase should be DEVELOPMENT"
            );

            IOS.Task[] memory tasks = os56.tasks(daoData.symbol);
            assertGt(tasks.length, 0, "there are unsolved tasks on Development phase");
        }

        // ------------------------------ fill TGE funding, refresh daoData
        {
            assertEq(
                OsUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.TGE_1),
                type(uint).max,
                "TGE funding should not exist yet"
            );

            ITokenomics.Funding memory funding = OsUtilsLib.generateTGEFunding();

            os56.updateFunding(daoData.symbol, funding);

            bytes32 proposalId = OsUtilsLib.getLastProposalId(os56, daoData.symbol);

            vm.prank(MULTISIG);
            os56.receiveVotingResults(proposalId, true);

            daoData = os56.getDAO(daoData.symbol);
            assertEq(
                OsUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.TGE_1), 1, "TGE funding should be added"
            );
        }

        // ------------------------------ fix units
        {
            IDAOUnit.UnitUiLink[] memory ui = new IDAOUnit.UnitUiLink[](1);
            ui[0] = IDAOUnit.UnitUiLink({href: "https://mvp.ui", title: "OS MVO"});

            IDAOUnit.UnitInfo[] memory units = new IDAOUnit.UnitInfo[](1);
            units[0] = IDAOUnit.UnitInfo({
                unitId: daoData.units[0].unitId,
                name: daoData.units[0].name,
                status: IDAOUnit.UnitStatus.LIVE_2,
                unitType: daoData.units[0].unitType,
                revenueShare: daoData.units[0].revenueShare,
                ui: ui,
                emoji: daoData.units[0].emoji,
                api: daoData.units[0].api
            });

            os56.updateUnits(daoData.symbol, units);
            bytes32 proposalId = OsUtilsLib.getLastProposalId(os56, daoData.symbol);

            vm.prank(MULTISIG);
            os56.receiveVotingResults(proposalId, true);
        }

        // ------------------------------ fix images
        {
            ITokenomics.DaoImages memory images = ITokenomics.DaoImages({
                seedToken: "/seedALIENS.png",
                tgeToken: "/ALIENS.png",
                token: "/tgeALIENS.png",
                xToken: "/xALIENS.png",
                daoToken: "/ALIENS_DAO.png"
            });
            os56.updateImages(daoData.symbol, images);

            bytes32 proposalId = OsUtilsLib.getLastProposalId(os56, daoData.symbol);
            vm.prank(MULTISIG);
            os56.receiveVotingResults(proposalId, true);
        }

        // ------------------------------ add vesting
        {
            uint fundingIndex = OsUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.TGE_1);
            ITokenomics.Funding memory tgeFunding = daoData.tokenomics.funding[fundingIndex];

            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = OsUtilsLib.generateVesting("Development", tgeFunding.end);

            os56.updateVesting(daoData.symbol, vesting);

            bytes32 proposalId = OsUtilsLib.getLastProposalId(os56, daoData.symbol);
            vm.prank(MULTISIG);
            os56.receiveVotingResults(proposalId, true);
        }

        // ------------------------------ owner of DAO is seed token
        assertEq(os56.getDAOOwner(daoData.symbol), daoData.deployments.seedToken, "owner should be seed token");

        // ------------------------------ try fund on not funding phase
        {
            vm.expectRevert(IOS.NotFundingPhase.selector);
            os56.fund(daoData.symbol, 1e18);

            vm.expectRevert(IOS.WaitFundingStart.selector);
            os56.changePhase(daoData.symbol);
        }

        // ------------------------------ TGE phase started (DEVELOPMENT done), refresh daoData
        {
            skip(180 days);

            os56.changePhase(daoData.symbol);
            daoData = os56.getDAO(daoData.symbol);

            assertEq(uint(daoData.phase), uint(ITokenomics.LifecyclePhase.TGE_4), "phase should be TGE");
            IOS.Task[] memory tasks = os56.tasks(daoData.symbol);
            assertGt(tasks.length, 0, "there are unsolved tasks on TGE phase");
        }

        // ------------------------------ setup TGE token
        OsUtilsLib.setupTgeToken(vm, os56, MULTISIG, daoData.deployments.tgeToken);

        // ------------------------------ TGE funders
        {
            // first seeder
            deal(asset, FIRST_SEEDER, 10_000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(os56), 10_000e18);

            vm.prank(FIRST_SEEDER);
            os56.fund(daoData.symbol, 10_000e18);

            assertEq(
                IERC20(daoData.deployments.tgeToken).balanceOf(FIRST_SEEDER),
                10_000e18,
                "third seeder seed token balance after funding"
            );

            // assume here that first seeder already has 100000000e18 received in seed round
            vm.expectRevert(IOS.RaiseMaxExceed.selector);
            vm.prank(FIRST_SEEDER);
            os56.fund(daoData.symbol, 100000000e18);

            // third seeder
            deal(asset, THIRD_SEEDER, 100_000e18);

            vm.prank(THIRD_SEEDER);
            IERC20(asset).approve(address(os56), 100_000e18);

            vm.prank(THIRD_SEEDER);
            os56.fund(daoData.symbol, 100_000e18);

            assertEq(
                IERC20(daoData.deployments.tgeToken).balanceOf(THIRD_SEEDER),
                100_000e18,
                "third seeder seed token balance after funding"
            );
        }

        // ------------------------------ LIVE CLIFF, refresh daoData
        {
            vm.expectRevert(IOS.WaitFundingEnd.selector);
            os56.changePhase(daoData.symbol);

            skip(8 days);

            os56.changePhase(daoData.symbol);

            daoData = os56.getDAO(daoData.symbol);

            assertEq(uint(daoData.phase), uint(ITokenomics.LifecyclePhase.LIVE_CLIFF_5), "phase should be LIVE_CLIFF");
        }

        // ------------------------------ LIVE VESTING, refresh daoData
        {
            vm.expectRevert(IOS.WaitVestingStart.selector);
            os56.changePhase(daoData.symbol);

            skip(200 days);

            os56.changePhase(daoData.symbol);

            daoData = os56.getDAO(daoData.symbol);

            assertEq(uint(daoData.phase), uint(ITokenomics.LifecyclePhase.LIVE_VESTING_6), "phase should be VESTING");

            IOS.Task[] memory tasks = os56.tasks(daoData.symbol);
            assertEq(tasks.length, 0, "all tasks should be solved on LIVE_VESTING phase"); // todo add task "distribute vesting funds to leverage token"
        }

        // ------------------------------ LIVE, refresh daoData
        {
            vm.expectRevert(IOS.WaitVestingEnd.selector);
            os56.changePhase(daoData.symbol);

            skip(4000 days);

            os56.changePhase(daoData.symbol);

            daoData = os56.getDAO(daoData.symbol);

            assertEq(uint(daoData.phase), uint(ITokenomics.LifecyclePhase.LIVE_7), "phase should be LIVE");
            IOS.Task[] memory tasks = os56.tasks(daoData.symbol);
            assertEq(tasks.length, 0, "all tasks should be solved on LIVE phase");
        }

        // ------------------------------ Try to update funding, vesting - bad paths
        {
            for (uint i = 0; i < daoData.tokenomics.funding.length; i++) {
                ITokenomics.Funding memory funding = ITokenomics.Funding({
                    fundingType: daoData.tokenomics.funding[i].fundingType,
                    start: daoData.tokenomics.funding[i].start,
                    end: daoData.tokenomics.funding[i].end,
                    minRaise: daoData.tokenomics.funding[i].minRaise,
                    maxRaise: 90_000e18,
                    raised: daoData.tokenomics.funding[i].raised,
                    claim: daoData.tokenomics.funding[i].claim
                });

                vm.expectRevert(IOS.TooLateToUpdateSuchFunding.selector);
                os56.updateFunding(daoData.symbol, funding);
            }

            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = OsUtilsLib.generateVesting("Development", 1);

            vm.expectRevert(IOS.TooLateToUpdateVesting.selector);
            os56.updateVesting(daoData.symbol, vesting);
        }
    }

    function lifeCycleDaoApes1(IOS os1) internal {
        address asset = os1.getChainSettings().exchangeAsset;

        // ------------------------------ Create DAO
        {
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
            funding[0] = OsUtilsLib.generateSeedFunding(
                7 days, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
            );

            ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
            activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

            ITokenomics.DaoParameters memory params = OsUtilsLib.generateDaoParams(30, 90);

            os1.createDAO("Apes Syndicate", "APES", activity, params, funding);
        }

        // todo other OS instances must see a symbol of new DAO

        ITokenomics.DaoData memory daoData = os1.getDAO("APES");

        // ------------------------------ Update images, units, socials, vesting
        {
            ITokenomics.DaoImages memory images = ITokenomics.DaoImages({
                seedToken: "/seedApes.png", tgeToken: "", token: "/apes.png", xToken: "", daoToken: ""
            });
            os1.updateImages(daoData.symbol, images);

            IDAOUnit.UnitInfo[] memory units = new IDAOUnit.UnitInfo[](1);
            units[0] = IDAOUnit.UnitInfo({
                unitId: "aliens:os",
                name: "DAO Factory",
                status: IDAOUnit.UnitStatus.BUILDING_1,
                unitType: uint16(IDAOUnit.UnitType.DEFI_PROTOCOL_1),
                revenueShare: 100,
                ui: new IDAOUnit.UnitUiLink[](0),
                emoji: "",
                api: new string[](0)
            });
            os1.updateUnits(daoData.symbol, units);

            string[] memory socials = new string[](2);
            socials[0] = "https://a.aa/a";
            socials[1] = "https://b.bb/b";

            os1.updateSocials(daoData.symbol, socials);
            uint fundingIndex = OsUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.SEED_0);
            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = OsUtilsLib.generateVesting("Development", daoData.tokenomics.funding[fundingIndex].end);

            os1.updateVesting(daoData.symbol, vesting);
        }

        // ------------------------------ apes forgot they created DRAFT
        {
            skip(15 days);

            vm.expectRevert(IOS.TooLateSoSetupFundingAgain.selector);
            os1.changePhase(daoData.symbol);

            ITokenomics.Funding memory funding = OsUtilsLib.generateSeedFunding(
                7 days, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
            );
            os1.updateFunding(daoData.symbol, funding);
        }

        // ------------------------------ change phase to SEED, refresh daoData
        {
            skip(7 days + 1); // todo why do we need +1 second here?

            os1.changePhase(daoData.symbol);
            ITokenomics.DaoData memory daoDataAfter = os1.getDAO(daoData.symbol);

            assertEq(uint8(daoDataAfter.phase), uint8(ITokenomics.LifecyclePhase.SEED_1), "phase should be SEED");
            daoData = os1.getDAO(daoData.symbol);

            // setup seed token
            OsUtilsLib.setupSeedToken(vm, os1, MULTISIG, daoData.deployments.seedToken);
        }

        // ------------------------------ Fund small amount - funding is failed, refresh daoData
        {
            deal(asset, FIRST_SEEDER, 1000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(os1), 1000e18);

            vm.prank(FIRST_SEEDER);
            os1.fund(daoData.symbol, 1000e18);

            skip(127 days);

            os1.changePhase(daoData.symbol);
            daoData = os1.getDAO(daoData.symbol);

            assertEq(
                uint8(daoData.phase), uint8(ITokenomics.LifecyclePhase.SEED_FAILED_2), "phase should be SEED_FAILED"
            );
        }

        // ------------------------------  First sender returns his funds
        {
            IERC20(daoData.deployments.seedToken).approve(address(os1), type(uint).max);

            //            vm.prank(FIRST_SEEDER);
            //            os56.refund(daoData.symbol); // todo
        }
    }

    function lifeCycleDaoMachines10(IOS os1) internal {
        address asset = os1.getChainSettings().exchangeAsset;

        // ------------------------------ Create DAO
        {
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](2);
            funding[0] = OsUtilsLib.generateSeedFunding(
                7 days, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
            );
            funding[1] = OsUtilsLib.generateTGEFunding();

            ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
            activity[0] = ITokenomics.Activity.MEV_SEARCHER_2;

            ITokenomics.DaoParameters memory params = OsUtilsLib.generateDaoParams(14, 99);

            os1.createDAO("Machines Cartel", "MACHINE", activity, params, funding);
        }

        // todo other OS instances must see a symbol of new DAO

        ITokenomics.DaoData memory daoData = os1.getDAO("MACHINE");

        // ------------------------------ Update images, units, socials, vesting
        {
            ITokenomics.DaoImages memory images = ITokenomics.DaoImages({
                seedToken: "/seedMACHINE.png",
                tgeToken: "/MACHINE.png",
                token: "/saleMACHINE.png",
                xToken: "/xMACHINE.png",
                daoToken: "/MACHINE_DAO.png"
            });
            os1.updateImages(daoData.symbol, images);

            IDAOUnit.UnitInfo[] memory units = new IDAOUnit.UnitInfo[](1);
            units[0] = IDAOUnit.UnitInfo({
                unitId: "MACHINES:MEVBOT",
                name: "MEV searcher",
                status: IDAOUnit.UnitStatus.LIVE_2,
                unitType: uint16(IDAOUnit.UnitType.MEV_3),
                revenueShare: 100,
                ui: new IDAOUnit.UnitUiLink[](0),
                emoji: "",
                api: new string[](0)
            });
            os1.updateUnits(daoData.symbol, units);

            string[] memory socials = new string[](2);
            socials[0] = "https://a.aa/a";
            socials[1] = "https://b.bb/b";
            os1.updateSocials(daoData.symbol, socials);

            uint fundingIndex = OsUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.SEED_0);
            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = OsUtilsLib.generateVesting("Development", daoData.tokenomics.funding[fundingIndex].end);

            os1.updateVesting(daoData.symbol, vesting);
        }

        // ------------------------------ change phase to SEED, refresh daoData
        {
            skip(7 days + 1); // todo why do we need +1 second here?

            os1.changePhase(daoData.symbol);
            ITokenomics.DaoData memory daoDataAfter = os1.getDAO(daoData.symbol);

            assertEq(uint8(daoDataAfter.phase), uint8(ITokenomics.LifecyclePhase.SEED_1), "phase should be SEED");
            daoData = os1.getDAO(daoData.symbol);

            // setup seed token
            OsUtilsLib.setupSeedToken(vm, os1, MULTISIG, daoData.deployments.seedToken);
        }

        // ------------------------------ Fund enough amount, refresh daoData
        {
            deal(asset, FIRST_SEEDER, 50000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(os1), 50000e18);

            vm.prank(FIRST_SEEDER);
            os1.fund(daoData.symbol, 50000e18);

            skip(127 days);

            os1.changePhase(daoData.symbol);
            daoData = os1.getDAO(daoData.symbol);

            assertEq(
                uint8(daoData.phase), uint8(ITokenomics.LifecyclePhase.DEVELOPMENT_3), "phase should be DEVELOPMENT"
            );
        }

        // ------------------------------ Switch to TGE, refresh daoData
        {
            skip(180 days);

            os1.changePhase(daoData.symbol);
            daoData = os1.getDAO(daoData.symbol);

            assertEq(uint8(daoData.phase), uint8(ITokenomics.LifecyclePhase.TGE_4), "phase should be TGE");

            // setup TGE token
            OsUtilsLib.setupTgeToken(vm, os1, MULTISIG, daoData.deployments.tgeToken);
        }

        // ------------------------------ Fund NOT enough amount, TGE failed, refresh daoData
        {
            // first seeder funds small amount
            deal(asset, FIRST_SEEDER, 1e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(os1), 1e18);

            vm.prank(FIRST_SEEDER);
            os1.fund(daoData.symbol, 1e18);

            // second seeder funds small amount
            deal(asset, SECOND_SEEDER, 2e18);

            vm.prank(SECOND_SEEDER);
            IERC20(asset).approve(address(os1), 2e18);

            vm.prank(SECOND_SEEDER);
            os1.fund(daoData.symbol, 2e18);

            skip(180 days);

            os1.changePhase(daoData.symbol);
            daoData = os1.getDAO(daoData.symbol);

            assertEq(
                uint8(daoData.phase),
                uint8(ITokenomics.LifecyclePhase.DEVELOPMENT_3),
                "phase should be DEVELOPMENT again"
            );
        }

        // ------------------------------ Reject proposal
        {
            string[] memory socials = new string[](2);
            socials[0] = "https://a.aa/a11";
            socials[1] = "https://b.bb/b22";

            os1.updateSocials(daoData.symbol, socials);

            bytes32 proposalId = OsUtilsLib.getLastProposalId(os1, daoData.symbol);

            vm.prank(MULTISIG);
            os1.receiveVotingResults(proposalId, false);
        }

        // ------------------------------ First seeker refunds funds
        {
        // todo
        }

        // ------------------------------ New TGE started
        {
        // todo
        }

        // ------------------------------ Second seeker is NOT able to refund because new TGE started
        {
        // todo
        }
    }

    //endregion ------------------------------ Life cycles logic
}
