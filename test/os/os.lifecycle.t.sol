// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IControllable2} from "../../src/interfaces/IControllable2.sol";
import {IDAOUnit, IDAOAgent, ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {IOS, OS} from "../../src/os/OS.sol";
import {OsLib} from "../../src/os/libs/OsLib.sol";
import {OsUtilsLib} from "./utils/OsUtilsLib.sol";
import {Proxy} from "../../src/core/proxy/Proxy.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract OsLifeCycleTestOsLifeCycleTest is Test {
    address internal immutable MULTISIG;
    address internal constant FIRST_SEEDER = address(0x1111);
    address internal constant SECOND_SEEDER = address(0x2222);

    address internal usdc;

    constructor() {
        // vm.selectFork(vm.createFork(vm.envString("SONIC_RPC_URL"), FORK_BLOCK));
        MULTISIG = makeAddr("multisig");
    }

    /// @notice Test single DAO life cycle
    function testLifeCycle56() public {
        // ------------------------------ Create new DAO
        IOS os56 = OsUtilsLib.createOsInstance(vm, MULTISIG);

        address asset = os56.getChainSettings().exchangeAsset;

        {
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
            funding[0] = OsUtilsLib.generateSeedFunding();

            ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](2);
            activity[0] = ITokenomics.Activity.BUILDER_3;
            activity[1] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

            ITokenomics.DaoParameters memory params = OsUtilsLib.generateDaoParams(365, 100);

            os56.createDAO("Aliens Community", "ALIENS", activity, params, funding);
        }

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

        // ------------------------------ setup seed token
        {
            ITokenomics.DaoData memory dao = os56.getDAO("ALIENS");
            OsUtilsLib.setupSeedToken(vm, os56, MULTISIG, dao.deployments.seedToken);
        }

        // todo other OS instances must see a symbol of new DAO

        // ------------------------------ SEED started. First seeder
        {
            deal(asset, FIRST_SEEDER, 5000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(os56), 5000e18);

            vm.prank(FIRST_SEEDER);
            os56.fund(daoData.symbol, 1000e18);

            assertEq(IERC20(asset).balanceOf(FIRST_SEEDER), 4000e18, "first seeder balance after funding");
        }

        // ------------------------------ since seed has funds first governance proposal can be created
    }

    function _showTasks(IOS.Task[] memory tasks) internal pure {
        for (uint i; i < tasks.length; i++) {
            console.log(tasks[i].name);
        }
    }
}
