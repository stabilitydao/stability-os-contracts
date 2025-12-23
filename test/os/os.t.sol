// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol"; // todo upgradable
import {IOS, OS} from "../../src/os/OS.sol";
import {OsLib} from "../../src/os/libs/OsLib.sol";
import {IDAOUnit, IDAOAgent, ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IControllable2} from "../../src/interfaces/IControllable2.sol";
import {Proxy} from "../../src/core/proxy/Proxy.sol";
import {OsUtilsLib} from "./utils/OsUtilsLib.sol";

contract OsTest is Test {
    uint public constant FORK_BLOCK = 58135155; // Dec-17-2025 05:45:24 AM +UTC

    string internal constant DAO_SYMBOL = "SPACE";
    string internal constant DAO_NAME = "SpaceSwap";

    address internal immutable MULTISIG;

    constructor() {
        // vm.selectFork(vm.createFork(vm.envString("SONIC_RPC_URL"), FORK_BLOCK));
        MULTISIG = makeAddr("multisig");
    }

    //region ----------------------------------- Unit tests
    function testStorageLocation() public pure {
        assertEq(
            keccak256(abi.encode(uint(keccak256("erc7201:stability-os-contracts.OS")) - 1)) & ~bytes32(uint(0xff)),
            OsLib.OS_STORAGE_LOCATION,
            "OS_STORAGE_LOCATION"
        );
    }

    function testCreateDAO() public {
        IOS os = OsUtilsLib.createOsInstance(vm, MULTISIG);

        // -------------------- Prepare test data
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = OsUtilsLib.generateSeedFunding();

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = OsUtilsLib.generateDaoParams(365, 100);
        os.createDAO(DAO_NAME, DAO_SYMBOL, activity, params, funding);

        ITokenomics.DaoData memory dao = os.getDAO(DAO_SYMBOL);
        assertEq(dao.name, DAO_NAME, "expected name");
        // todo assertEq(os.eventsCount(), 1);

        // -------------------- bad name length
        vm.expectRevert(abi.encodeWithSelector(IOS.NameLength.selector, uint(28)));
        os.createDAO("SpaceSwap_000000000000000000", "SPACE2", activity, params, funding);

        // -------------------- bad symbol length
        vm.expectRevert(abi.encodeWithSelector(IOS.SymbolLength.selector, uint(9)));
        os.createDAO("SpaceSwap", "SPACESWAP", activity, params, funding);

        // -------------------- not unique symbol
        vm.expectRevert(abi.encodeWithSelector(IOS.SymbolNotUnique.selector, "SPACE"));
        os.createDAO("SpaceSwap", "SPACE", activity, params, funding);

        { // -------------------- bad vePeriod
            ITokenomics.DaoParameters memory paramsBadVe = OsUtilsLib.generateDaoParams(
                365 * 5,
                /* 1825 */
                100
            );
            vm.expectRevert(abi.encodeWithSelector(IOS.VePeriod.selector, uint(1825)));
            os.createDAO("SpaceSwap", "SPACE1", activity, paramsBadVe, funding);
        }

        { // -------------------- bad pvpFee
            ITokenomics.DaoParameters memory paramsBadPvP = OsUtilsLib.generateDaoParams(365, 101);
            vm.expectRevert(abi.encodeWithSelector(IOS.PvPFee.selector, uint(101)));
            os.createDAO("SpaceSwap", "SPACE1", activity, paramsBadPvP, funding);
        }

        { // -------------------- no funding
            ITokenomics.Funding[] memory emptyFunding = new ITokenomics.Funding[](0);
            vm.expectRevert(IOS.NeedFunding.selector);
            os.createDAO("SpaceSwap", "SPACE1", activity, params, emptyFunding);
        }
    }

    function testAddLiveDAO() public {
        IOS os = OsUtilsLib.createOsInstance(vm, MULTISIG);

        // todo only verifier

        ITokenomics.DaoData memory daoOrigin = OsUtilsLib.createTestDaoData();

        vm.prank(MULTISIG);
        os.addLiveDAO(daoOrigin);

        ITokenomics.DaoData memory readDao = os.getDAO(daoOrigin.symbol);

        _assertDaoEqual(daoOrigin, readDao);
    }

    function testAddLiveDaoBadPaths() public {
        IOS os = OsUtilsLib.createOsInstance(vm, MULTISIG);
        ITokenomics.DaoData memory daoOrigin = OsUtilsLib.createTestDaoData();

        vm.prank(MULTISIG);
        os.addLiveDAO(daoOrigin);

        // -------------------- not unique symbol
        vm.expectRevert(abi.encodeWithSelector(IOS.SymbolNotUnique.selector, "testdao"));
        vm.prank(MULTISIG);
        os.addLiveDAO(daoOrigin);

        // -------------------- todo only verifier
        // os.addLiveDAO(daoOrigin);

        // -------------------- todo validation
    }

    function testTasks() public {
        // todo
    }

    //endregion ----------------------------------- Unit tests

    //region ----------------------------------- Change life phase

    // todo

    //endregion ----------------------------------- Change life phase

    //region ----------------------------------- Update dao images
    function testUpdateDaoImagesInstant() public {
        IOS os = OsUtilsLib.createOsInstance(vm, MULTISIG);
        ITokenomics.DaoData memory dao = OsUtilsLib.createDaoInstance(os, DAO_SYMBOL, DAO_NAME);

        os.updateImages(
            dao.symbol,
            ITokenomics.DaoImages({seedToken: "new/images/seed.png", tgeToken: "", token: "", xToken: "", daoToken: ""})
        );

        {
            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);
            assertEq(daoAfter.images.seedToken, "new/images/seed.png", "seedToken updated");
            assertEq(daoAfter.images.tgeToken, dao.images.tgeToken, "tgeToken unchanged");
            assertEq(daoAfter.images.token, dao.images.token, "token unchanged");
            assertEq(daoAfter.images.xToken, dao.images.xToken, "xToken unchanged");
            assertEq(daoAfter.images.daoToken, dao.images.daoToken, "daoToken unchanged");
        }

        os.updateImages(
            dao.symbol, ITokenomics.DaoImages({seedToken: "1", tgeToken: "2", token: "3", xToken: "4", daoToken: "5"})
        );

        {
            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);
            assertEq(daoAfter.images.seedToken, "1", "seedToken updated");
            assertEq(daoAfter.images.tgeToken, "2", "tgeToken updated");
            assertEq(daoAfter.images.token, "3", "token updated");
            assertEq(daoAfter.images.xToken, "4", "xToken updated");
            assertEq(daoAfter.images.daoToken, "5", "daoToken updated");
        }
    }

    // todo phase seed

    // todo bad paths
    //endregion ----------------------------------- Update dao images

    //region ----------------------------------- Update socials
    function testUpdateDaoSocialsInstant() public {
        IOS os = OsUtilsLib.createOsInstance(vm, MULTISIG);
        ITokenomics.DaoData memory dao = OsUtilsLib.createDaoInstance(os, DAO_SYMBOL, DAO_NAME);

        {
            string[] memory socials = new string[](3);
            socials[0] = "1";
            socials[1] = "2";
            socials[2] = "3";
            os.updateSocials(dao.symbol, socials);

            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);
            assertEq(daoAfter.socials.length, 3, "socials length");
            assertEq(daoAfter.socials[0], "1", "socials[0] updated");
            assertEq(daoAfter.socials[1], "2", "socials[1] updated");
            assertEq(daoAfter.socials[2], "3", "socials[2] updated");
        }

        {
            string[] memory socials = new string[](2);
            socials[0] = "1111";
            socials[1] = ""; // (!) empty
            os.updateSocials(dao.symbol, socials);

            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);
            assertEq(daoAfter.socials.length, 2, "socials length");
            assertEq(daoAfter.socials[0], "1111", "socials[0] updated");
            assertEq(daoAfter.socials[1], "", "socials[1] updated");
        }
    }

    //endregion ----------------------------------- Update socials

    //region ----------------------------------- Update units
    function testUpdateUnitsInstant() public {
        IOS os = OsUtilsLib.createOsInstance(vm, MULTISIG);
        ITokenomics.DaoData memory dao = OsUtilsLib.createDaoInstance(os, DAO_SYMBOL, DAO_NAME);

        {
            IDAOUnit.UnitUiLink[] memory notEmptyUi = new IDAOUnit.UnitUiLink[](2);
            notEmptyUi[0] = IDAOUnit.UnitUiLink({label: "link1", url: "https://link1.com"});
            notEmptyUi[1] = IDAOUnit.UnitUiLink({label: "link2", url: "https://link2.com"});

            string[] memory notEmptyApi = new string[](3);
            notEmptyApi[0] = "https://api1.com";
            notEmptyApi[1] = "https://api2.com";
            notEmptyApi[2] = "https://api3.com";

            ITokenomics.UnitInfo[] memory units = new ITokenomics.UnitInfo[](2);
            units[0] = IDAOUnit.UnitInfo({
                unitId: "unitA",
                name: "Unit A",
                status: IDAOUnit.UnitStatus.LIVE_2,
                unitType: uint16(1),
                revenueShare: 1000,
                emoji: "emoji1",
                ui: notEmptyUi,
                api: notEmptyApi
            });
            units[1] = IDAOUnit.UnitInfo({
                unitId: "unitB1",
                name: "Unit B1",
                status: IDAOUnit.UnitStatus.BUILDING_1,
                unitType: uint16(2),
                revenueShare: 2000,
                emoji: "emoji2",
                ui: new IDAOUnit.UnitUiLink[](0),
                api: new string[](0)
            });
            os.updateUnits(dao.symbol, units);

            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);
            assertEq(daoAfter.units.length, 2, "units length");
            assertTrue(keccak256(abi.encode(units[0])) == keccak256(abi.encode(daoAfter.units[0])), "eq1");
            assertTrue(keccak256(abi.encode(units[1])) == keccak256(abi.encode(daoAfter.units[1])), "eq2");
        }

        {
            IDAOUnit.UnitUiLink[] memory notEmptyUi = new IDAOUnit.UnitUiLink[](1);
            notEmptyUi[0] = IDAOUnit.UnitUiLink({label: "link2", url: "https://link2.com"});

            string[] memory notEmptyApi = new string[](1);
            notEmptyApi[0] = "https://api1.com";

            ITokenomics.UnitInfo[] memory units = new ITokenomics.UnitInfo[](1);
            units[0] = IDAOUnit.UnitInfo({
                unitId: "unitAAAA",
                name: "Unit AAAA",
                status: IDAOUnit.UnitStatus.BUILDING_1,
                unitType: uint16(2),
                revenueShare: 2000,
                emoji: "emoji222",
                ui: notEmptyUi,
                api: notEmptyApi
            });
            os.updateUnits(dao.symbol, units);

            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);
            assertEq(daoAfter.units.length, 1, "units length");
            assertEq(daoAfter.units[0].ui.length, 1, "ui length");
            assertEq(daoAfter.units[0].api.length, 1, "api length");
            assertTrue(keccak256(abi.encode(units[0])) == keccak256(abi.encode(daoAfter.units[0])), "eq3");
        }
    }

    //endregion ----------------------------------- Update units

    //region ----------------------------------- Update funding
    function testUpdateFundingInstant() public {
        IOS os = OsUtilsLib.createOsInstance(vm, MULTISIG);
        ITokenomics.DaoData memory dao = OsUtilsLib.createDaoInstance(os, DAO_SYMBOL, DAO_NAME);

        ITokenomics.Funding memory seed;
        seed.fundingType = ITokenomics.FundingType.SEED_0;
        seed.start = 100;
        seed.end = 200;
        seed.minRaise = 1000;
        seed.maxRaise = 5000;
        seed.raised = 250;
        seed.claim = 1;

        {
            os.updateFunding(dao.symbol, seed);

            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);
            assertEq(daoAfter.tokenomics.funding.length, 1, "funding length");

            ITokenomics.Funding memory fundingAfter = daoAfter.tokenomics.funding[0];

            assertEq(uint8(fundingAfter.fundingType), uint8(seed.fundingType));
            assertEq(uint64(fundingAfter.start), uint64(seed.start));
            assertEq(uint64(fundingAfter.end), uint64(seed.end));
            assertEq(fundingAfter.minRaise, seed.minRaise);
            assertEq(fundingAfter.maxRaise, seed.maxRaise);
            assertEq(fundingAfter.raised, seed.raised);
            assertEq(fundingAfter.claim, seed.claim);
        }

        {
            ITokenomics.Funding memory tge;
            tge.fundingType = ITokenomics.FundingType.TGE_1;
            tge.start = 1001;
            tge.end = 2002;
            tge.minRaise = 10003;
            tge.maxRaise = 50004;
            tge.raised = 2505;
            tge.claim = 16;

            os.updateFunding(dao.symbol, tge);

            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);
            assertEq(daoAfter.tokenomics.funding.length, 2, "funding length");

            ITokenomics.Funding memory seed0 = daoAfter.tokenomics.funding[0];
            ITokenomics.Funding memory tge1 = daoAfter.tokenomics.funding[1];

            assertEq(uint8(tge1.fundingType), uint8(tge.fundingType), "tge type");
            assertEq(uint64(tge1.start), uint64(tge.start), "tge start");
            assertEq(uint64(tge1.end), uint64(tge.end), "tge end");
            assertEq(tge1.minRaise, tge.minRaise, "tge minRaise");
            assertEq(tge1.maxRaise, tge.maxRaise, "tge maxRaise");
            assertEq(tge1.raised, tge.raised, "tge raised");
            assertEq(tge1.claim, tge.claim, "tge claimed");

            assertEq(uint8(seed0.fundingType), uint8(seed.fundingType), "seed fundingType is unchanged");
            assertEq(uint64(seed0.start), uint64(seed.start), "seed start is unchanged");
            assertEq(uint64(seed0.end), uint64(seed.end), "seed end is unchanged");
            assertEq(seed0.minRaise, seed.minRaise, "seed minRaise is unchanged");
            assertEq(seed0.maxRaise, seed.maxRaise, "seed maxRaise is unchanged");
            assertEq(seed0.raised, seed.raised, "seed raised is unchanged");
            assertEq(seed0.claim, seed.claim, "seed claim is unchanged");
        }
    }

    //endregion ----------------------------------- Update funding

    //region ----------------------------------- Update vesting
    function testUpdateVestingInstant() public {
        IOS os = OsUtilsLib.createOsInstance(vm, MULTISIG);
        ITokenomics.DaoData memory dao = OsUtilsLib.createDaoInstance(os, DAO_SYMBOL, DAO_NAME);

        {
            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](2);
            vesting[0] =
                ITokenomics.Vesting({name: "Team", description: "team vesting", allocation: 1000, start: 1, end: 100});
            vesting[1] =
                ITokenomics.Vesting({name: "Seed", description: "seed vesting", allocation: 2000, start: 2, end: 200});

            os.updateVesting(dao.symbol, vesting);

            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);
            assertEq(daoAfter.tokenomics.vesting.length, 2, "vesting length");

            assertEq(
                keccak256(abi.encode(daoAfter.tokenomics.vesting[0])),
                keccak256(abi.encode(vesting[0])),
                "vesting[0] eq"
            );
            assertEq(
                keccak256(abi.encode(daoAfter.tokenomics.vesting[1])),
                keccak256(abi.encode(vesting[1])),
                "vesting[1] eq"
            );
        }

        {
            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = ITokenomics.Vesting({
                name: "Team3", description: "team vesting3", allocation: 10003, start: 3, end: 300
            });

            os.updateVesting(dao.symbol, vesting);

            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);
            assertEq(daoAfter.tokenomics.vesting.length, 1, "vesting length 2");

            assertEq(
                keccak256(abi.encode(daoAfter.tokenomics.vesting[0])),
                keccak256(abi.encode(vesting[0])),
                "vesting[0] eq"
            );
        }
    }

    //endregion ----------------------------------- Update vesting

    //region ----------------------------------- Update naming
    function testUpdateNamingInstant() public {
        IOS os = OsUtilsLib.createOsInstance(vm, MULTISIG);
        ITokenomics.DaoData memory dao = OsUtilsLib.createDaoInstance(os, DAO_SYMBOL, DAO_NAME);

        {
            ITokenomics.DaoNames memory naming = ITokenomics.DaoNames({name: "New DAO Name", symbol: "NEWDS"});

            os.updateNaming(dao.symbol, naming);

            ITokenomics.DaoData memory daoAfter = os.getDAO(naming.symbol);

            assertEq(daoAfter.name, naming.name, "name updated");
            assertEq(daoAfter.deployer, dao.deployer, "deployer wasn't changed");
        }
    }

    //endregion ----------------------------------- Update naming

    //region ----------------------------------- Update dao parameters
    function testUpdateDaoParametersInstant() public {
        IOS os = OsUtilsLib.createOsInstance(vm, MULTISIG);
        ITokenomics.DaoData memory dao = OsUtilsLib.createDaoInstance(os, DAO_SYMBOL, DAO_NAME);

        {
            ITokenomics.DaoParameters memory a;
            a.vePeriod = 100;
            a.pvpFee = 10;
            a.minPower = 1000;
            a.ttBribe = 1;
            a.recoveryShare = 2;
            a.proposalThreshold = 50;

            os.updateDaoParameters(dao.symbol, a);

            ITokenomics.DaoData memory daoAfter = os.getDAO(dao.symbol);

            assertEq(keccak256(abi.encode(daoAfter.params)), keccak256(abi.encode(a)), "params");
        }
    }

    //endregion ----------------------------------- Update dao parameters

    //region ----------------------------------- Internal logic
    function _assertDaoEqual(ITokenomics.DaoData memory expected, ITokenomics.DaoData memory actual) internal pure {
        // basic fields
        assertEq(uint(uint8(expected.phase)), uint(uint8(actual.phase)), "phase");
        assertEq(expected.symbol, actual.symbol, "symbol");
        assertEq(expected.name, actual.name, "name");
        assertEq(expected.deployer, actual.deployer, "deployer");

        // socials
        assertEq(expected.socials.length, actual.socials.length, "socials.length");
        for (uint i = 0; i < expected.socials.length; i++) {
            assertEq(expected.socials[i], actual.socials[i], "socials[i]");
        }

        // activity
        assertEq(expected.activity.length, actual.activity.length, "activity.length");
        for (uint i = 0; i < expected.activity.length; i++) {
            assertEq(uint(uint8(expected.activity[i])), uint(uint8(actual.activity[i])), "activity[i]");
        }

        // images
        assertEq(expected.images.seedToken, actual.images.seedToken, "images.seedToken");
        assertEq(expected.images.tgeToken, actual.images.tgeToken, "images.tgeToken");
        assertEq(expected.images.token, actual.images.token, "images.token");
        assertEq(expected.images.xToken, actual.images.xToken, "images.xToken");
        assertEq(expected.images.daoToken, actual.images.daoToken, "images.daoToken");

        // deployments
        assertEq(expected.deployments.seedToken, actual.deployments.seedToken, "deploy.seedToken");
        assertEq(expected.deployments.tgeToken, actual.deployments.tgeToken, "deploy.tgeToken");
        assertEq(expected.deployments.token, actual.deployments.token, "deploy.token");
        assertEq(expected.deployments.xToken, actual.deployments.xToken, "deploy.xToken");
        assertEq(expected.deployments.staking, actual.deployments.staking, "deploy.staking");
        assertEq(expected.deployments.daoToken, actual.deployments.daoToken, "deploy.daoToken");
        assertEq(expected.deployments.revenueRouter, actual.deployments.revenueRouter, "deploy.revenueRouter");
        assertEq(expected.deployments.recovery, actual.deployments.recovery, "deploy.recovery");
        assertTrue(
            keccak256(abi.encode(expected.deployments.vesting)) == keccak256(abi.encode(actual.deployments.vesting)),
            "deploy.vesting hash"
        );
        assertEq(expected.deployments.tokenBridge, actual.deployments.tokenBridge, "deploy.tokenBridge");
        assertEq(expected.deployments.xTokenBridge, actual.deployments.xTokenBridge, "deploy.xTokenBridge");
        assertEq(expected.deployments.daoTokenBridge, actual.deployments.daoTokenBridge, "deploy.daoTokenBridge");

        // params
        assertEq(expected.params.vePeriod, actual.params.vePeriod, "params.vePeriod");
        assertEq(expected.params.pvpFee, actual.params.pvpFee, "params.pvpFee");
        assertEq(expected.params.minPower, actual.params.minPower, "params.minPower");
        assertEq(expected.params.ttBribe, actual.params.ttBribe, "params.ttBribe");
        assertEq(expected.params.recoveryShare, actual.params.recoveryShare, "params.recoveryShare");
        assertEq(expected.params.proposalThreshold, actual.params.proposalThreshold, "params.proposalThreshold");

        // units
        assertEq(expected.units.length, actual.units.length, "units.length");
        for (uint i = 0; i < expected.units.length; i++) {
            ITokenomics.UnitInfo memory eu = expected.units[i];
            ITokenomics.UnitInfo memory au = actual.units[i];

            assertEq(eu.unitId, au.unitId, "unit.unitId");
            assertEq(eu.name, au.name, "unit.name");
            assertEq(uint(uint8(eu.status)), uint(uint8(au.status)), "unit.status");
            assertEq(eu.unitType, au.unitType, "unit.unitType");
            assertEq(eu.revenueShare, au.revenueShare, "unit.revenueShare");
            assertEq(eu.emoji, au.emoji, "unit.emoji");

            // ui links
            assertEq(eu.ui.length, au.ui.length, "unit.ui.length");
            for (uint j = 0; j < eu.ui.length; j++) {
                assertEq(eu.ui[j].label, au.ui[j].label, "unit.ui.label");
                assertEq(eu.ui[j].url, au.ui[j].url, "unit.ui.url");
            }

            // api endpoints
            assertEq(eu.api.length, au.api.length, "unit.api.length");
            for (uint j = 0; j < eu.api.length; j++) {
                assertEq(eu.api[j], au.api[j], "unit.api");
            }
        }

        // agents
        assertEq(expected.agents.length, actual.agents.length, "agents.length");
        for (uint i = 0; i < expected.agents.length; i++) {
            ITokenomics.AgentInfo memory ea = expected.agents[i];
            ITokenomics.AgentInfo memory aa = actual.agents[i];

            // api
            assertEq(ea.api.length, aa.api.length, "agent.api.length");
            for (uint j = 0; j < ea.api.length; j++) {
                assertEq(ea.api[j], aa.api[j], "agent.api");
            }

            // roles
            assertEq(ea.roles.length, aa.roles.length, "agent.roles.length");
            for (uint j = 0; j < ea.roles.length; j++) {
                assertEq(ea.roles[j], aa.roles[j], "agent.roles");
            }

            assertEq(ea.name, aa.name, "agent.name");

            // directives
            assertEq(ea.directives.length, aa.directives.length, "agent.directives.length");
            for (uint j = 0; j < ea.directives.length; j++) {
                assertEq(ea.directives[j], aa.directives[j], "agent.directives");
            }

            assertEq(ea.image, aa.image, "agent.image");
            assertEq(ea.telegram, aa.telegram, "agent.telegram");
        }

        // tokenomics: funding
        assertEq(expected.tokenomics.funding.length, actual.tokenomics.funding.length, "tokenomics.funding.length");
        for (uint i = 0; i < expected.tokenomics.funding.length; i++) {
            ITokenomics.Funding memory ef = expected.tokenomics.funding[i];
            ITokenomics.Funding memory af = actual.tokenomics.funding[i];

            assertEq(uint(uint8(ef.fundingType)), uint(uint8(af.fundingType)), "funding.fundingType");
            assertEq(ef.start, af.start, "funding.start");
            assertEq(ef.end, af.end, "funding.end");
            assertEq(ef.minRaise, af.minRaise, "funding.minRaise");
            assertEq(ef.maxRaise, af.maxRaise, "funding.maxRaise");
            assertEq(ef.raised, af.raised, "funding.raised");
            assertEq(ef.claim, af.claim, "funding.claim");
        }

        // vesting
        assertEq(expected.tokenomics.vesting.length, actual.tokenomics.vesting.length, "tokenomics.vesting.length");
        for (uint i = 0; i < expected.tokenomics.vesting.length; i++) {
            ITokenomics.Vesting memory ev = expected.tokenomics.vesting[i];
            ITokenomics.Vesting memory av = actual.tokenomics.vesting[i];

            assertEq(ev.name, av.name, "vesting.name");
            assertEq(ev.description, av.description, "vesting.description");
            assertEq(ev.allocation, av.allocation, "vesting.allocation");
            assertEq(ev.start, av.start, "vesting.start");
            assertEq(ev.end, av.end, "vesting.end");
        }

        // initialChain
        assertEq(expected.tokenomics.initialChain, actual.tokenomics.initialChain, "tokenomics.initialChain");
    }
    //endregion ----------------------------------- Internal logic
}
