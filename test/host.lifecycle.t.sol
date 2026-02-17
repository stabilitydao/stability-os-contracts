// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SampleDataLib} from "./utils/SampleDataLib.sol";
import {HostUtilsLib} from "./utils/HostUtilsLib.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IAuthority} from "../src/interfaces/IAuthority.sol";
import {IDAOData} from "../src/interfaces/IDAOData.sol";
import {ISegment4} from "../src/interfaces/ISegment4.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHostCodec} from "../src/interfaces/IHostCodec.sol";
import {IDataReader} from "../src/interfaces/IDataReader.sol";
import {IHost} from "../src/interfaces/IHost.sol";
import {IProxyFactory} from "../src/interfaces/IProxyFactory.sol";
import {ITokenomics} from "../src/interfaces/ITokenomics.sol";
import {MockHostBridge} from "./mocks/MockHostBridge.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AuthorityAccessUtils} from "./intents/access/AuthorityAccessUtils.sol";

contract HostLifeCycleTest is Test {
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
        IHost host56 = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = _createHostCodec(host56);

        AuthorityAccessUtils.setupHostAsAuthorityAdmin(vm, host56, MULTISIG);

        lifeCycleDaoAlien56(host56, codec);

        // ------------------------------ Ensure that first DAO becomes Host DAO
        {
            uint uid = host56.hostDaoUid();
            IDAOData.DaoData memory data = IDataReader(host56.getChainSettings().dataReader).getDAO("ALIENS");
            assertEq(data.uid, uid, "ALIENS is Host dao");
        }

        // ------------------------------ Second DAO
        // second DAO are APES syndicate
        // they cant build but need their own DeFi lending protocol
        // they do many errors

        // todo Second DAO should be created on chain 1 but currently it's created on chain 56
        lifeCycleDaoApes1(host56, codec);

        // ------------------------------ Third DAO
        // third DAO are Machines Cartel
        // todo Third DAO should be created on chain 10 but currently it's created on chain 56
        lifeCycleDaoMachines10(host56, codec);
    }

    function testLifeCycleWithSalt() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = _createHostCodec(host);
        AuthorityAccessUtils.setupHostAsAuthorityAdmin(vm, host, MULTISIG);
        lifeCycleWithSalt(host, codec);
    }

    //region ------------------------------ Life cycles logic
    function lifeCycleDaoAlien56(IHost host_, IHostCodec codec_) internal {
        address asset = host_.getChainSettings().exchangeAsset;

        // ------------------------------ Create DAO
        _dealAndApprove(host_);
        IDAOData.DaoData memory daoData = HostUtilsLib.createAliensDao(vm, host_, "ALIENS");

        // ------------------------------ other OS instances must see a symbol of new DAO
        {
            MockHostBridge bridge = MockHostBridge(host_.getChainSettings().hostBridge);
            bytes memory message = bridge.receivedMessages(uint(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0));
            (, string memory symbol) = abi.decode(message, (uint16, string));
            assertEq(symbol, daoData.symbol, "bridge received new DAO symbol message");
        }

        // ------------------------------ 7 days later (draft phase)
        {
            skip(7 days);

            vm.expectRevert(IHost.SolveTasksFirst.selector);
            host_.changePhase(daoData.symbol);
        }

        // ------------------------------ check what aliens need to do
        ISegment4.UnitEmitData memory unitMetadata0 = ISegment4.UnitEmitData({
            name: "DAO Factory",
            description: "description of DAO Factory unit",
            status: ISegment4.UnitStatus.BUILDING_3,
            unitType: ISegment4.UnitType.DEFI_PROTOCOL_1,
            revenueShare: 100,
            ui: new ISegment4.UnitUiLink[](0),
            emoji: "",
            api: new string[](0),
            pool: SampleDataLib.getUnitPoolSample()
        });
        {
            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertGe(tasks.length, 2, "at least 2 unsolved tasks");

            // deployer drew token logotypes
            ITokenomics.DaoImages memory images = ITokenomics.DaoImages({
                seedToken: "/seedAliens.png", tgeToken: "", token: "/aliens.png", xToken: "", daoToken: ""
            });
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_IMAGES_0),
                codec_.encode(images, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            {
                IHost.Task[] memory tasksAfter = host_.tasks(daoData.symbol);
                assertLe(tasksAfter.length, tasks.length, "number of tasks should decrease");
            }

            // units project
            IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](1);
            ISegment4.UnitEmitData[] memory metas = new ISegment4.UnitEmitData[](1);
            metas[0] = unitMetadata0;
            units[0] = IDAOData.UnitDataInput({unitId: "aliens:os", developerUid: ""});
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
                codec_.encode(units, codec_.PAYLOAD_API_VERSION()),
                codec_.encode(metas, codec_.PAYLOAD_API_VERSION())
            );

            // registered socials
            string[] memory socials = SampleDataLib.getSocialsThree();

            HostUtilsLib.updateSocialsWithValidation(vm, MULTISIG, host_, codec_, daoData.symbol, socials);

            {
                IHost.Task[] memory tasksAfter = host_.tasks(daoData.symbol);
                assertEq(tasksAfter.length, 0, "all tasks solved");
            }
        }

        // ------------------------------ fix funding
        {
            ITokenomics.Funding memory funding = ITokenomics.Funding({
                fundingType: daoData.funding[0].fundingType,
                start: daoData.funding[0].start,
                end: daoData.funding[0].end,
                minRaise: daoData.funding[0].minRaise,
                maxRaise: 90_000e18,
                raised: daoData.funding[0].raised,
                claim: daoData.funding[0].claim
            });
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4),
                codec_.encode(funding, codec_.PAYLOAD_API_VERSION()),
                ""
            );
        }

        // ------------------------------ change phase to inception
        {
            host_.changePhase(daoData.symbol);
            IDAOData.DaoData memory daoDataAfter =
                IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);
            assertEq(
                uint8(daoDataAfter.phase), uint8(ITokenomics.LifecyclePhase.INCEPTION_1), "phase should be INCEPTION"
            );
        }

        // ------------------------------ phase cant be changed right now
        {
            vm.expectRevert(IHost.WaitFundingStart.selector);
            host_.changePhase(daoData.symbol);

            skip(24 days);
        }

        // ------------------------------ change phase to seed
        {
            host_.changePhase(daoData.symbol);
            IDAOData.DaoData memory daoDataAfter =
                IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(uint8(daoDataAfter.phase), uint8(ITokenomics.LifecyclePhase.SEED_2), "phase should be SEED");

            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertGt(tasks.length, 0, "at least 1 unsolved tasks");
        }

        // ------------------------------ refresh daoData
        {
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(IERC20Metadata(daoData.deployments.seedToken).name(), "Aliens Community SEED", "seed name");
            assertEq(IERC20Metadata(daoData.deployments.seedToken).symbol(), "seedALIENS", "seed symbol");
        }

        // ------------------------------ SEED started. First seeder
        {
            deal(asset, FIRST_SEEDER, 5000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(host_), 5000e18);

            vm.prank(FIRST_SEEDER);
            host_.fund(daoData.symbol, 1000e18);

            assertEq(IERC20(asset).balanceOf(FIRST_SEEDER), 4000e18, "first seeder balance after funding");
            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(FIRST_SEEDER),
                1000e18,
                "first seeder seed token balance after funding"
            );
        }

        // ------------------------------ since seed has funds first governance proposal can be created
        {
            string[] memory socials = SampleDataLib.getSocialsThree();

            (bytes32 proposalId, bytes memory payload, bytes memory inputPayload) =
                HostUtilsLib.updateSocialsWithValidation(vm, MULTISIG, host_, codec_, daoData.symbol, socials);
            assertEq(keccak256(payload), keccak256(inputPayload), "Emitted payload is exact same to initial one");

            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);

            IDAOData.DaoData memory daoAfter = IDataReader(host_.getChainSettings().dataReader).getDAO("ALIENS");
            assertEq(daoAfter.socials.length, 3, "socials should be updated after proposal");

            assertEq(
                keccak256(abi.encode(socials)), keccak256(abi.encode(daoAfter.socials)), "socials data should match"
            );

            vm.expectRevert(IHost.AlreadyReceived.selector);
            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);

            vm.expectRevert(IHost.IncorrectProposal.selector);
            vm.prank(MULTISIG);
            host_.receiveVotingResults(bytes32(uint(proposalId) + 1), true, payload);
        }

        // ------------------------------ Second seeder
        {
            deal(asset, SECOND_SEEDER, 10000e18);

            vm.prank(SECOND_SEEDER);
            IERC20(asset).approve(address(host_), type(uint).max);

            vm.prank(SECOND_SEEDER);
            host_.fund(daoData.symbol, 10000e18);

            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(SECOND_SEEDER),
                10000e18,
                "second seeder seed token balance after funding"
            );

            deal(asset, SECOND_SEEDER, 100000000e18);

            vm.expectRevert(IHost.RaiseMaxExceed.selector);
            vm.prank(SECOND_SEEDER);
            host_.fund(daoData.symbol, 100000000e18);
        }

        // ------------------------------ phase cant be changed right now
        {
            vm.expectRevert(IHost.WaitFundingEnd.selector);
            host_.changePhase(daoData.symbol);

            skip(100 days);
        }

        // ------------------------------ DEVELOPMENT phase started (SEED succeed), refresh daoData
        {
            host_.changePhase(daoData.symbol);
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(
                uint8(daoData.phase), uint8(ITokenomics.LifecyclePhase.DEVELOPMENT_4), "phase should be DEVELOPMENT"
            );

            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertGt(tasks.length, 0, "there are unsolved tasks on Development phase");
        }

        // ------------------------------ fill TGE funding, refresh daoData
        {
            assertEq(
                HostUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.TGE_1),
                type(uint).max,
                "TGE funding should not exist yet"
            );

            ITokenomics.Funding memory funding = HostUtilsLib.generateTGEFunding();

            vm.recordLogs();
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4),
                codec_.encode(funding, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);

            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);

            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);
            assertEq(
                HostUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.TGE_1), 1, "TGE funding should be added"
            );
        }

        // ------------------------------ fix units
        {
            ISegment4.UnitUiLink[] memory ui = new ISegment4.UnitUiLink[](1);
            ui[0] = ISegment4.UnitUiLink({href: "https://mvp.ui", title: "OS MVO"});

            IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](1);
            ISegment4.UnitEmitData[] memory metas = new ISegment4.UnitEmitData[](1);
            metas[0] = ISegment4.UnitEmitData({
                name: unitMetadata0.name,
                description: unitMetadata0.description,
                status: ISegment4.UnitStatus.BUILDING_3, // (!) any status is allowed here, we don't check it
                unitType: unitMetadata0.unitType,
                revenueShare: unitMetadata0.revenueShare,
                ui: unitMetadata0.ui,
                emoji: unitMetadata0.emoji,
                api: unitMetadata0.api,
                pool: unitMetadata0.pool
            });
            units[0] = IDAOData.UnitDataInput({unitId: daoData.units[0].unitId, developerUid: ""});

            vm.recordLogs();
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
                codec_.encode(units, codec_.PAYLOAD_API_VERSION()),
                codec_.encode(metas, codec_.PAYLOAD_API_VERSION())
            );

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);

            // put some amount on unit balance - it means that the unit is "live"
            address exchangeAsset = host_.getChainSettings().exchangeAsset;
            deal(exchangeAsset, address(this), 1000e18);
            IERC20(exchangeAsset).approve(address(host_), 1000e18);
            host_.revenue(daoData.symbol, daoData.units[0].unitId, exchangeAsset, 1000e18);

            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);
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
            vm.recordLogs();
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_IMAGES_0),
                codec_.encode(images, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);
            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);
        }

        // ------------------------------ add vesting
        {
            uint fundingIndex = HostUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.TGE_1);
            ITokenomics.Funding memory tgeFunding = daoData.funding[fundingIndex];

            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = HostUtilsLib.generateVesting("Development", tgeFunding.end);

            vm.recordLogs();
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_VESTING_5),
                codec_.encode(vesting, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);
            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);
        }

        // ------------------------------ owner of DAO is seed token
        assertEq(host_.ownerDAO(daoData.symbol), daoData.deployments.seedToken, "owner should be seed token");

        // ------------------------------ try fund on not funding phase
        {
            vm.expectRevert(IHost.NotFundingPhase.selector);
            host_.fund(daoData.symbol, 1e18);

            vm.expectRevert(IHost.WaitFundingStart.selector);
            host_.changePhase(daoData.symbol);
        }

        // ------------------------------ TGE phase started (DEVELOPMENT done), refresh daoData
        {
            skip(180 days);

            host_.changePhase(daoData.symbol);
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(uint(daoData.phase), uint(ITokenomics.LifecyclePhase.TGE_5), "phase should be TGE");
            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertGt(tasks.length, 0, "there are unsolved tasks on TGE phase");
        }

        assertEq(IERC20Metadata(daoData.deployments.tgeToken).name(), "Aliens Community PRESALE", "tge name");
        assertEq(IERC20Metadata(daoData.deployments.tgeToken).symbol(), "saleALIENS", "tge symbol");

        // ------------------------------ TGE funders
        {
            // first seeder
            deal(asset, FIRST_SEEDER, 10_000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(host_), 10_000e18);

            vm.prank(FIRST_SEEDER);
            host_.fund(daoData.symbol, 10_000e18);

            assertEq(
                IERC20(daoData.deployments.tgeToken).balanceOf(FIRST_SEEDER),
                10_000e18,
                "third seeder seed token balance after funding"
            );

            // assume here that first seeder already has 100000000e18 received in seed round
            vm.expectRevert(IHost.RaiseMaxExceed.selector);
            vm.prank(FIRST_SEEDER);
            host_.fund(daoData.symbol, 100000000e18);

            // third seeder
            deal(asset, THIRD_SEEDER, 100_000e18);

            vm.prank(THIRD_SEEDER);
            IERC20(asset).approve(address(host_), 100_000e18);

            vm.prank(THIRD_SEEDER);
            host_.fund(daoData.symbol, 100_000e18);

            assertEq(
                IERC20(daoData.deployments.tgeToken).balanceOf(THIRD_SEEDER),
                100_000e18,
                "third seeder seed token balance after funding"
            );
        }

        // ------------------------------ LIVE CLIFF, refresh daoData
        {
            vm.expectRevert(IHost.WaitFundingEnd.selector);
            host_.changePhase(daoData.symbol);

            skip(8 days);

            host_.changePhase(daoData.symbol);

            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(uint(daoData.phase), uint(ITokenomics.LifecyclePhase.LIVE_CLIFF_6), "phase should be LIVE_CLIFF");
        }

        // ------------------------------ LIVE VESTING, refresh daoData
        {
            vm.expectRevert(IHost.WaitVestingStart.selector);
            host_.changePhase(daoData.symbol);

            skip(200 days);

            host_.changePhase(daoData.symbol);

            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(uint(daoData.phase), uint(ITokenomics.LifecyclePhase.LIVE_VESTING_7), "phase should be VESTING");

            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertEq(tasks.length, 0, "all tasks should be solved on LIVE_VESTING phase"); // todo add task "distribute vesting funds to leverage token"
        }

        // ------------------------------ LIVE, refresh daoData
        {
            vm.expectRevert(IHost.WaitVestingEnd.selector);
            host_.changePhase(daoData.symbol);

            skip(4000 days);

            host_.changePhase(daoData.symbol);

            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(uint(daoData.phase), uint(ITokenomics.LifecyclePhase.LIVE_8), "phase should be LIVE");
            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertEq(tasks.length, 0, "all tasks should be solved on LIVE phase");
        }

        // ------------------------------ Try to update funding, vesting - bad paths
        {
            for (uint i = 0; i < daoData.funding.length; i++) {
                ITokenomics.Funding memory funding = ITokenomics.Funding({
                    fundingType: daoData.funding[i].fundingType,
                    start: daoData.funding[i].start,
                    end: daoData.funding[i].end,
                    minRaise: daoData.funding[i].minRaise,
                    maxRaise: 90_000e18,
                    raised: daoData.funding[i].raised,
                    claim: daoData.funding[i].claim
                });

                bytes memory payload = codec_.encode(funding, codec_.PAYLOAD_API_VERSION());
                vm.expectRevert(IHost.TooLateToUpdateSuchFunding.selector);
                host_.updateDAO(daoData.symbol, uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4), payload, "");
            }

            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = HostUtilsLib.generateVesting("Development", 1);

            {
                bytes memory payload = codec_.encode(vesting, codec_.PAYLOAD_API_VERSION());
                vm.expectRevert(IHost.TooLateToUpdateVesting.selector);
                host_.updateDAO(daoData.symbol, uint16(ITokenomics.DAOAction.UPDATE_VESTING_5), payload, "");
            }
        }
    }

    function lifeCycleDaoApes1(IHost host_, IHostCodec codec_) internal {
        address asset = host_.getChainSettings().exchangeAsset;

        // ------------------------------ Create DAO
        _dealAndApprove(host_);
        IDAOData.DaoData memory daoData = HostUtilsLib.createApesDao(vm, host_);

        // ------------------------------ other OS instances must see a symbol of new DAO
        {
            MockHostBridge bridge = MockHostBridge(host_.getChainSettings().hostBridge);
            bytes memory message = bridge.receivedMessages(uint(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0));
            (, string memory symbol) = abi.decode(message, (uint16, string));
            assertEq(symbol, daoData.symbol, "bridge received new DAO symbol message");
        }

        // ------------------------------ Update images, units, socials, vesting
        {
            ITokenomics.DaoImages memory images = ITokenomics.DaoImages({
                seedToken: "/seedApes.png", tgeToken: "", token: "/apes.png", xToken: "", daoToken: ""
            });
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_IMAGES_0),
                codec_.encode(images, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) =
                SampleDataLib.getUnitsSingle("aliens:os");
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
                codec_.encode(units, codec_.PAYLOAD_API_VERSION()),
                codec_.encode(metas, codec_.PAYLOAD_API_VERSION())
            );

            string[] memory socials = SampleDataLib.getSocialsThree();

            HostUtilsLib.updateSocialsWithValidation(vm, MULTISIG, host_, codec_, daoData.symbol, socials);

            // todo we cannot add vesting here because tge.claim is 0
            //            uint fundingIndex = HostUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.SEED_0);
            //            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            //            vesting[0] = HostUtilsLib.generateVesting("Development", daoData.funding[fundingIndex].end);
            //
            //            host_.updateDAO(
            //                daoData.symbol,
            //                uint16(ITokenomics.DAOAction.UPDATE_VESTING_5),
            //                codec_.encode(vesting, codec_.PAYLOAD_API_VERSION()),
            //                ""
            //            );
        }

        // ------------------------------ change phase to inception
        host_.changePhase(daoData.symbol);

        // ------------------------------ apes forgot they created INCEPTION
        {
            skip(15 days);

            // todo Inception phase
            //            vm.expectRevert(IHost.TooLateSoSetupFundingAgain.selector);
            //            host_.changePhase(daoData.symbol);

            ITokenomics.Funding memory funding = HostUtilsLib.generateSeedFunding(
                7 days,
                HostUtilsLib.DEFAULT_SEED_DURATION,
                HostUtilsLib.DEFAULT_SEED_MIN_RAISE,
                HostUtilsLib.DEFAULT_SEED_MAX_RAISE
            );
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4),
                codec_.encode(funding, codec_.PAYLOAD_API_VERSION()),
                ""
            );
        }

        // ------------------------------ change phase to SEED, refresh daoData
        {
            skip(7 days + 1); // todo why do we need +1 second here?

            host_.changePhase(daoData.symbol);
            IDAOData.DaoData memory daoDataAfter =
                IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(uint8(daoDataAfter.phase), uint8(ITokenomics.LifecyclePhase.SEED_2), "apes phase should be SEED");
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);
        }

        // ------------------------------ Fund small amount - funding is failed, refresh daoData
        {
            deal(asset, FIRST_SEEDER, 1000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(host_), 1000e18);

            vm.prank(FIRST_SEEDER);
            host_.fund(daoData.symbol, 1000e18);

            skip(127 days);

            host_.changePhase(daoData.symbol);
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(
                uint8(daoData.phase), uint8(ITokenomics.LifecyclePhase.SEED_FAILED_3), "phase should be SEED_FAILED"
            );

            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(FIRST_SEEDER),
                1000e18,
                "first seeder seed token balance after funding"
            );
        }

        // ------------------------------  First sender returns his funds
        {
            IERC20(daoData.deployments.seedToken).approve(address(host_), type(uint).max);

            assertEq(IERC20(asset).balanceOf(FIRST_SEEDER), 0, "first seeder has no asset before refund");

            vm.prank(FIRST_SEEDER);
            host_.refund(daoData.symbol);

            assertEq(IERC20(asset).balanceOf(FIRST_SEEDER), 1000e18, "first seeder balance after refund");
            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(FIRST_SEEDER),
                0,
                "first seeder doesn't have seed tokens any more"
            );
        }
    }

    function lifeCycleDaoMachines10(IHost host_, IHostCodec codec_) internal {
        address asset = host_.getChainSettings().exchangeAsset;

        // ------------------------------ Create DAO
        _dealAndApprove(host_);
        IDAOData.DaoData memory daoData = HostUtilsLib.createDaoMachines(vm, host_);

        // ------------------------------ other OS instances must see a symbol of new DAO
        {
            MockHostBridge bridge = MockHostBridge(host_.getChainSettings().hostBridge);
            bytes memory message = bridge.receivedMessages(uint(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0));
            (, string memory symbol) = abi.decode(message, (uint16, string));
            assertEq(symbol, daoData.symbol, "bridge received new DAO symbol message");
        }

        // ------------------------------ other OS instances must see a symbol of new DAO
        {
            MockHostBridge bridge = MockHostBridge(host_.getChainSettings().hostBridge);
            bytes memory message = bridge.receivedMessages(uint(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0));
            (, string memory symbol) = abi.decode(message, (uint16, string));
            assertEq(symbol, daoData.symbol, "bridge received new DAO symbol message");
        }

        // ------------------------------ Update images, units, socials, vesting
        {
            ITokenomics.DaoImages memory images = ITokenomics.DaoImages({
                seedToken: "/seedMACHINE.png",
                tgeToken: "/MACHINE.png",
                token: "/saleMACHINE.png",
                xToken: "/xMACHINE.png",
                daoToken: "/MACHINE_DAO.png"
            });
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_IMAGES_0),
                codec_.encode(images, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) =
                SampleDataLib.getUnitsSingle("MACHINES:MEVBOT");
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
                codec_.encode(units, codec_.PAYLOAD_API_VERSION()),
                codec_.encode(metas, codec_.PAYLOAD_API_VERSION())
            );

            string[] memory socials = SampleDataLib.getSocialsThree();

            HostUtilsLib.updateSocialsWithValidation(vm, MULTISIG, host_, codec_, daoData.symbol, socials);

            uint fundingIndex = HostUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.SEED_0);
            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = HostUtilsLib.generateVesting("Development", daoData.funding[fundingIndex].end);

            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_VESTING_5),
                codec_.encode(vesting, codec_.PAYLOAD_API_VERSION()),
                ""
            );
        }

        daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

        {
            // put some amount on unit balance - it means that the unit is "live"
            address exchangeAsset = host_.getChainSettings().exchangeAsset;
            deal(exchangeAsset, address(this), 1000e18);
            IERC20(exchangeAsset).approve(address(host_), 1000e18);
            host_.revenue(daoData.symbol, daoData.units[0].unitId, exchangeAsset, 1000e18);
        }

        // ------------------------------ change phase to SEED, refresh daoData
        {
            // change phase to inception
            host_.changePhase(daoData.symbol);

            skip(7 days + 1); // todo why do we need +1 second here?

            host_.changePhase(daoData.symbol);
            IDAOData.DaoData memory daoDataAfter =
                IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(
                uint8(daoDataAfter.phase), uint8(ITokenomics.LifecyclePhase.SEED_2), "machines phase should be SEED"
            );
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);
        }

        // ------------------------------ Fund enough amount, refresh daoData
        {
            deal(asset, FIRST_SEEDER, 50000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(host_), 50000e18);

            vm.prank(FIRST_SEEDER);
            host_.fund(daoData.symbol, 50000e18);

            skip(127 days);

            host_.changePhase(daoData.symbol);
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(
                uint8(daoData.phase), uint8(ITokenomics.LifecyclePhase.DEVELOPMENT_4), "phase should be DEVELOPMENT"
            );
            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(FIRST_SEEDER),
                50000e18,
                "first seeder has expected amount of seed tokens after funding"
            );
        }

        // ------------------------------ Switch to TGE, refresh daoData
        {
            skip(180 days);

            host_.changePhase(daoData.symbol);
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(uint8(daoData.phase), uint8(ITokenomics.LifecyclePhase.TGE_5), "phase should be TGE");
        }

        // ------------------------------ Fund NOT enough amount, TGE failed, refresh daoData
        {
            // first seeder funds small amount
            deal(asset, FIRST_SEEDER, 1e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(host_), 1e18);

            vm.prank(FIRST_SEEDER);
            host_.fund(daoData.symbol, 1e18);

            // second seeder funds small amount
            deal(asset, SECOND_SEEDER, 2e18);

            vm.prank(SECOND_SEEDER);
            IERC20(asset).approve(address(host_), 2e18);

            vm.prank(SECOND_SEEDER);
            host_.fund(daoData.symbol, 2e18);

            skip(180 days);

            host_.changePhase(daoData.symbol);
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(
                uint8(daoData.phase),
                uint8(ITokenomics.LifecyclePhase.DEVELOPMENT_4),
                "phase should be DEVELOPMENT again"
            );
        }

        // ------------------------------ Reject proposal
        {
            string[] memory socials = SampleDataLib.getSocialsThree();

            (bytes32 proposalId, bytes memory payload,) =
                HostUtilsLib.updateSocialsWithValidation(vm, MULTISIG, host_, codec_, daoData.symbol, socials);

            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, false, payload);
        }

        // ------------------------------ First seeker refunds (tge) funds
        {
            IERC20(daoData.deployments.seedToken).approve(address(host_), type(uint).max);

            assertEq(IERC20(asset).balanceOf(FIRST_SEEDER), 0, "first seeder has no asset before refund");
            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(FIRST_SEEDER),
                50000e18,
                "first seeder has expected amount of seed tokens before refund"
            );
            assertEq(
                IERC20(daoData.deployments.tgeToken).balanceOf(FIRST_SEEDER),
                1e18,
                "first seeder has expected amount of tge tokens before refund"
            );

            vm.prank(FIRST_SEEDER);
            host_.refund(daoData.symbol);

            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(FIRST_SEEDER),
                50000e18,
                "balance of seed tokens of first seeder remains the same after refund"
            );
            assertEq(
                IERC20(daoData.deployments.tgeToken).balanceOf(FIRST_SEEDER),
                0,
                "first seeder doesn't have tge tokens any more"
            );
            assertEq(IERC20(asset).balanceOf(FIRST_SEEDER), 1e18, "first seeder balance after refund");
        }

        // ------------------------------ Update Dao Parameters
        {
            vm.recordLogs();
            ITokenomics.DaoParameters memory daoParameters = HostUtilsLib.generateDaoParams(777, 40);
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6),
                codec_.encode(daoParameters, codec_.PAYLOAD_API_VERSION()),
                ""
            );
            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);

            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);

            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);
            assertEq(
                keccak256(abi.encode(daoData.params)),
                keccak256(abi.encode(daoParameters)),
                "dao parameters should be updated after proposal"
            );
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

    /// @dev Try to create DAO contracts with salt
    function lifeCycleWithSalt(IHost host_, IHostCodec codec_) internal {
        address asset = host_.getChainSettings().exchangeAsset;

        // ------------------------------ Create DAO
        _dealAndApprove(host_);
        IDAOData.DaoData memory daoData = HostUtilsLib.createAliensDao(vm, host_, "ALIENS");

        // ------------------------------ solve required tasks
        {
            skip(7 days);

            // deployer drew token logotypes
            ITokenomics.DaoImages memory images = ITokenomics.DaoImages({
                seedToken: "/seedAliens.png", tgeToken: "1", token: "/aliens.png", xToken: "2", daoToken: "3"
            });
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_IMAGES_0),
                codec_.encode(images, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            // units project
            (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) =
                SampleDataLib.getUnitsSingle();

            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
                codec_.encode(units, codec_.PAYLOAD_API_VERSION()),
                codec_.encode(metas, codec_.PAYLOAD_API_VERSION())
            );

            // registered socials
            string[] memory socials = SampleDataLib.getSocialsThree();

            HostUtilsLib.updateSocialsWithValidation(vm, MULTISIG, host_, codec_, daoData.symbol, socials);

            ITokenomics.Funding memory funding = ITokenomics.Funding({
                fundingType: daoData.funding[0].fundingType,
                start: daoData.funding[0].start,
                end: daoData.funding[0].end,
                minRaise: daoData.funding[0].minRaise,
                maxRaise: 90_000e18,
                raised: daoData.funding[0].raised,
                claim: daoData.funding[0].claim
            });

            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4),
                codec_.encode(funding, codec_.PAYLOAD_API_VERSION()),
                ""
            );
        }

        // ------------------------------ set SALT for seed token
        address predictedSeedAddress;
        {
            IProxyFactory proxyFactory = IProxyFactory(_getAuthority(host_).PROXY_FACTORY());

            bytes32[] memory salts = new bytes32[](1);
            salts[0] = "0x0101";

            predictedSeedAddress = IProxyFactory(proxyFactory).predictAddress(salts[0]);

            uint16[] memory indices = new uint16[](1);
            indices[0] = uint16(ITokenomics.ContractIndices.SEED_TOKEN_1);

            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_SALT_7),
                codec_.encode(indices, salts, codec_.PAYLOAD_API_VERSION()),
                ""
            );
        }

        // ------------------------------ change phase to inception
        host_.changePhase(daoData.symbol);

        // ------------------------------ change phase to seed
        {

            skip(24 days);

            host_.changePhase(daoData.symbol);
        }

        // ------------------------------ refresh daoData
        {
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(daoData.deployments.seedToken, predictedSeedAddress, "seed token address matches predicted");

            assertEq(
                host_.salt(daoData.symbol, uint16(ITokenomics.ContractIndices.SEED_TOKEN_1)),
                "0x0101",
                "SEED salt should not change after proposal"
            );
        }

        // ------------------------------ SEED started. First seeder
        {
            deal(asset, FIRST_SEEDER, 5000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(host_), 5000e18);

            vm.prank(FIRST_SEEDER);
            host_.fund(daoData.symbol, 1000e18);

            assertEq(IERC20(asset).balanceOf(FIRST_SEEDER), 4000e18, "first seeder balance after funding");
            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(FIRST_SEEDER),
                1000e18,
                "first seeder seed token balance after funding"
            );
        }

        // ------------------------------ set SALT for tge token through proposal
        address predictedTgeAddress;
        {
            bytes memory input;
            {
                IProxyFactory proxyFactory = IProxyFactory(_getAuthority(host_).PROXY_FACTORY());

                bytes32[] memory salts = new bytes32[](2);
                salts[0] = "0x0101";
                salts[1] = "0x0202";

                predictedTgeAddress = IProxyFactory(proxyFactory).predictAddress(salts[0]);

                uint16[] memory indices = new uint16[](2);
                indices[0] = uint16(ITokenomics.ContractIndices.SEED_TOKEN_1); // we can update seed token salt even if the token is already created
                indices[1] = uint16(ITokenomics.ContractIndices.TGE_TOKEN_2);

                input = codec_.encode(indices, salts, codec_.PAYLOAD_API_VERSION());
            }

            vm.recordLogs();
            host_.updateDAO(daoData.symbol, uint16(ITokenomics.DAOAction.UPDATE_SALT_7), input, "");

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);

            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);

            assertEq(
                host_.salt(daoData.symbol, uint16(ITokenomics.ContractIndices.SEED_TOKEN_1)),
                "0x0101",
                "SEED salt should not change after proposal"
            );
            assertEq(
                host_.salt(daoData.symbol, uint16(ITokenomics.ContractIndices.TGE_TOKEN_2)),
                "0x0202",
                "TGE salt should be updated after proposal"
            );
        }

        // ------------------------------ Second seeder
        {
            deal(asset, SECOND_SEEDER, 10000e18);

            vm.prank(SECOND_SEEDER);
            IERC20(asset).approve(address(host_), type(uint).max);

            vm.prank(SECOND_SEEDER);
            host_.fund(daoData.symbol, 10000e18);

            assertEq(
                IERC20(daoData.deployments.seedToken).balanceOf(SECOND_SEEDER),
                10000e18,
                "second seeder seed token balance after funding"
            );

            deal(asset, SECOND_SEEDER, 100000000e18);

            vm.expectRevert(IHost.RaiseMaxExceed.selector);
            vm.prank(SECOND_SEEDER);
            host_.fund(daoData.symbol, 100000000e18);
        }

        // ------------------------------ DEVELOPMENT phase started (SEED succeed), refresh daoData
        {
            skip(100 days);

            host_.changePhase(daoData.symbol);
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(
                uint8(daoData.phase), uint8(ITokenomics.LifecyclePhase.DEVELOPMENT_4), "phase should be DEVELOPMENT"
            );

            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertGt(tasks.length, 0, "there are unsolved tasks on Development phase");
        }

        // ------------------------------ fill TGE funding, refresh daoData
        {
            assertEq(
                HostUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.TGE_1),
                type(uint).max,
                "TGE funding should not exist yet"
            );

            ITokenomics.Funding memory funding = HostUtilsLib.generateTGEFunding();

            vm.recordLogs();
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4),
                codec_.encode(funding, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);

            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);

            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);
            assertEq(
                HostUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.TGE_1), 1, "TGE funding should be added"
            );
        }

        // ------------------------------ fix units
        {
            bytes memory input;
            bytes memory metadata;

            {
                (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) =
                    SampleDataLib.getUnitsSingle(daoData.units[0].unitId);

                input = codec_.encode(units, codec_.PAYLOAD_API_VERSION());
                metadata = codec_.encode(metas, codec_.PAYLOAD_API_VERSION());
            }

            vm.recordLogs();
            host_.updateDAO(daoData.symbol, uint16(ITokenomics.DAOAction.UPDATE_UNITS_3), input, metadata);

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);

            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);

            // put some amount on unit balance - it means that the unit is "live"
            address exchangeAsset = host_.getChainSettings().exchangeAsset;
            deal(exchangeAsset, address(this), 1000e18);
            IERC20(exchangeAsset).approve(address(host_), 1000e18);
            host_.revenue(daoData.symbol, daoData.units[0].unitId, exchangeAsset, 1000e18);
        }

        // ------------------------------ add vesting
        {
            uint fundingIndex = HostUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.TGE_1);
            ITokenomics.Funding memory tgeFunding = daoData.funding[fundingIndex];

            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = HostUtilsLib.generateVesting("Development", tgeFunding.end);

            vm.recordLogs();
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_VESTING_5),
                codec_.encode(vesting, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);
            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);
        }

        // ------------------------------ TGE phase started (DEVELOPMENT done), refresh daoData
        {
            skip(180 days);

            host_.changePhase(daoData.symbol);
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(uint(daoData.phase), uint(ITokenomics.LifecyclePhase.TGE_5), "phase should be TGE");
            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertGt(tasks.length, 0, "there are unsolved tasks on TGE phase");
        }

        assertEq(IERC20Metadata(daoData.deployments.tgeToken).name(), "Aliens Community PRESALE", "tge name");
        assertEq(IERC20Metadata(daoData.deployments.tgeToken).symbol(), "saleALIENS", "tge symbol");
    }

    //endregion ------------------------------ Life cycles logic

    //region ------------------------------ Utils
    /// @notice user should pay for DAO-creation
    function _dealAndApprove(IHost os_) internal {
        address exchangeAsset = os_.getChainSettings().exchangeAsset;
        uint amount = os_.getSettings().priceDao;
        deal(exchangeAsset, address(this), amount);
        IERC20(exchangeAsset).approve(address(os_), amount);
    }

    function _getAuthority(IHost host) internal view returns (IAuthority) {
        return IAuthority(IAccessManaged(address(host)).authority());
    }

    function _keepConsoleInImport() internal pure {
        console.log("hide warning about removing console from imports");
    }

    function _createHostCodec(IHost host) internal returns (IHostCodec) {
        return HostUtilsLib.createHostCodec(vm, MULTISIG, host);
    }
    //endregion ------------------------------ Utils
}
