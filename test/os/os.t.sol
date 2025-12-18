// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOS, OS} from "../../src/os/OS.sol";
import {IDAOUnit, IDAOAgent, ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {SonicConstantsLib} from "../../chains/SonicConstantsLib.sol";
import {console} from "forge-std/console.sol";

contract OsSonicTest is Test {
    uint public constant FORK_BLOCK = 58135155; // Dec-17-2025 05:45:24 AM +UTC

    string internal constant DAO_SYMBOL = "SPACE";
    string internal constant DAO_NAME = "SpaceSwap";

    constructor() {
        vm.selectFork(vm.createFork(vm.envString("SONIC_RPC_URL"), FORK_BLOCK));
    }

    //region ----------------------------------- Unit tests
    function testCreateDAO() public {
        IOS os = _createOsInstance();

        // -------------------- Prepare test data
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = _generateSeedFunding();

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = _generateDaoParams(365, 100);
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
            ITokenomics.DaoParameters memory paramsBadVe = _generateDaoParams(365 * 5 /* 1825 */, 100);
            vm.expectRevert(abi.encodeWithSelector(IOS.VePeriod.selector, uint(1825)));
            os.createDAO("SpaceSwap", "SPACE1", activity, paramsBadVe, funding);
        }

        { // -------------------- bad pvpFee
            ITokenomics.DaoParameters memory paramsBadPvP = _generateDaoParams(365, 101);
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
        IOS os = _createOsInstance();

        // todo only verifier


        ITokenomics.DaoData memory daoOrigin = this.createTestDaoData();
        os.addLiveDAO(daoOrigin);
        ITokenomics.DaoData memory readDao = os.getDAO(daoOrigin.symbol);

        _assertDaoEqual(daoOrigin, readDao);
    }

    function testAddLiveDaoBadPaths() public {
        IOS os = _createOsInstance();
        ITokenomics.DaoData memory daoOrigin = this.createTestDaoData();
        os.addLiveDAO(daoOrigin);

        // -------------------- not unique symbol
        vm.expectRevert(abi.encodeWithSelector(IOS.SymbolNotUnique.selector, "testdao"));
        os.addLiveDAO(daoOrigin);

        // -------------------- todo only verifier
        // os.addLiveDAO(daoOrigin);

        // -------------------- todo validation
    }


    //endregion ----------------------------------- Unit tests


    //region ----------------------------------- Internal logic
    function _createOsInstance() internal returns (IOS) {
        OS os = new OS(SonicConstantsLib.MULTISIG);
        _setOsSettings(os);
        return IOS(address(os));
    }

    function _setOsSettings(OS os) internal {
        // Prepare and set OS settings using the IOS.OsSettings struct
        os.setSettings(
            IOS.OsSettings({
                priceDao: 1000,
                priceUnit: 1000,
                priceOracle: 1000,
                priceBridge: 1000,
                minNameLength: 1,
                maxNameLength: 20,
                minSymbolLength: 1,
                maxSymbolLength: 7,
                minVePeriod: 14,
                maxVePeriod: 365 * 4,
                minPvPFee: 10,
                maxPvPFee: 100,
                minFundingDuration: 1,
                maxFundingDuration: 180,
                minAbsorbOfferUsd: 50000
            })
        );
    }

    /// @notice Generate a seed funding with sensible defaults relative to current block timestamp.
    /// @return A populated ITokenomics.Funding struct ready to be passed to createDAO/updateFunding.
    function _generateSeedFunding() internal view returns (ITokenomics.Funding memory) {
        // Defaults: delaySec = 30 days, duration = 90 days, minRaise = 10_000, maxRaise = 100_000
        uint64 delaySec = uint64(30 * 86400);
        uint64 duration = uint64(3 * 30 * 86400);

        uint64 start = uint64(block.timestamp + delaySec);
        uint64 endt = uint64(block.timestamp + delaySec + duration);

        return ITokenomics.Funding({
            fundingType: ITokenomics.FundingType.SEED_0,
            start: start,
            end: endt,
            minRaise: 10000,
            maxRaise: 100000,
            raised: 0,
            claim: 0
        });
    }

    function _generateDaoParams(uint32 vePeriod_, uint16 pvpFee_) internal pure returns (ITokenomics.DaoParameters memory) {
        return ITokenomics.DaoParameters({
            vePeriod: vePeriod_,
            pvpFee: pvpFee_,
            minPower: 0,
            ttBribe: 0,
            recoveryShare: 0,
            proposalThreshold: 0
        });
    }

    function createTestDaoData() external pure returns (ITokenomics.DaoData memory data) {
        // ---------------- base fields
        data.phase = ITokenomics.LifecyclePhase.DEVELOPMENT_3;
        data.symbol = "testdao";
        data.name = "Test DAO";
        data.deployer = address(0x123);

        // ---------------- socials
        data.socials = new string[](3);
        data.socials[0] = "https://twitter.com/testdao";
        data.socials[1] = "https://github.com/testdao";
        data.socials[2] = "https://discord.gg/testdao";

        // ---------------- activity
        data.activity = new ITokenomics.Activity[](2);
        data.activity[0] = ITokenomics.Activity.SAAS_OPERATOR_1;
        data.activity[1] = ITokenomics.Activity.BUILDER_3;

        // ---------------- images
        data.images = ITokenomics.DaoImages({
            seedToken: "images/seed.png",
            tgeToken: "images/tge.png",
            token: "images/token.png",
            xToken: "images/xtoken.png",
            daoToken: "images/daotoken.png"
        });

        // ---------------- Deployments
        data.deployments = ITokenomics.DaoDeploymentInfo({
            seedToken: address(0x1001),
            tgeToken: address(0x1002),
            token: address(0x1003),
            xToken: address(0x1004),
            staking: address(0x2001),
            daoToken: address(0x2002),
            revenueRouter: address(0x2003),
            recovery: address(0x2004),
            vesting: address(0x3001),
            tokenBridge: address(0x4001),
            xTokenBridge: address(0x4002),
            daoTokenBridge: address(0x4003)
        });

        data.units = new ITokenomics.UnitInfo[](0);
        data.agents = new ITokenomics.AgentInfo[](0);

        // ---------------- Create 3 units
        data.units = new ITokenomics.UnitInfo[](3);

        { // Unit 0: one UI link, two API endpoints
            ITokenomics.UnitUiLink[] memory ui0 = new ITokenomics.UnitUiLink[](1);
            ui0[0] = IDAOUnit.UnitUiLink({label: "Dashboard", url: "https://unit0.example/dashboard"});

            string[] memory api0 = new string[](2);
            api0[0] = "https://api.unit0.example/v1/status";
            api0[1] = "https://api.unit0.example/v1/metrics";

            data.units[0] = IDAOUnit.UnitInfo({
                unitId: "defi:protocolA",
                name: "Protocol A",
                status: IDAOUnit.UnitStatus.RESEARCH_0,
                unitType: uint16(IDAOUnit.UnitType.DEFI_PROTOCOL_1),
                revenueShare: 20000,
                emoji: "zzz",
                ui: ui0,
                api: api0
            });
        }

        { // Unit 1: two UI links, one API endpoint
            ITokenomics.UnitUiLink[] memory ui1 = new ITokenomics.UnitUiLink[](2);
            ui1[0] = IDAOUnit.UnitUiLink({label: "App", url: "https://unit1.example/app"});
            ui1[1] = IDAOUnit.UnitUiLink({label: "Docs", url: "https://unit1.example/docs"});

            string[] memory api1 = new string[](1);
            api1[0] = "https://api.unit1.example/";

            data.units[1] = IDAOUnit.UnitInfo({
                unitId: "saas:serviceX",
                name: "Service X",
                status: IDAOUnit.UnitStatus.BUILDING_1,
                unitType: uint16(IDAOUnit.UnitType.SAAS_2),
                revenueShare: 50000,
                emoji: "aaa",
                ui: ui1,
                api: api1
            });
        }

        { // Unit 2: no UI links, empty api array
            ITokenomics.UnitUiLink[] memory ui2 = new ITokenomics.UnitUiLink[](0);
            string[] memory api2 = new string[](0);

            data.units[2] = IDAOUnit.UnitInfo({
                unitId: "mev:botZ",
                name: "MEV Bot Z",
                status: IDAOUnit.UnitStatus.LIVE_2,
                unitType: uint16(IDAOUnit.UnitType.MEV_3),
                revenueShare: 80000,
                emoji: "aaaaaaaa",
                ui: ui2,
                api: api2
            });
        }

        // ---------------- Create 4 agents
        data.agents = new ITokenomics.AgentInfo[](4);

        { // Agent 0: single API, multiple directives
            string[] memory api0 = new string[](1);
            api0[0] = "https://agent0.example/api";

            uint8[] memory roles0 = new uint8[](1);
            roles0[0] = uint8(IDAOAgent.AgentRole.OPERATOR_0);

            string[] memory directives0 = new string[](2);
            directives0[0] = "Monitor network";
            directives0[1] = "Report incidents";

            data.agents[0] = IDAOAgent.AgentInfo({
                api: api0,
                roles: roles0,
                name: "Operator One",
                directives: directives0,
                image: "ipfs://QmAgent0Image",
                telegram: "@operator_one"
            });
        }

        { // Agent 1: two API endpoints, no directives
            string[] memory api1 = new string[](2);
            api1[0] = "https://agent1.example/status";
            api1[1] = "https://agent1.example/health";

            uint8[] memory roles1 = new uint8[](1);
            roles1[0] = uint8(IDAOAgent.AgentRole.OPERATOR_0);

            string[] memory directives1 = new string[](0);

            data.agents[1] = IDAOAgent.AgentInfo({
                api: api1,
                roles: roles1,
                name: "Relayer Team",
                directives: directives1,
                image: "https://cdn.example/relayer.png",
                telegram: "@relayer_team"
            });
        }

        { // Agent 2: no API endpoints, single directive
            string[] memory api2 = new string[](0);
            uint8[] memory roles2 = new uint8[](1);
            roles2[0] = uint8(IDAOAgent.AgentRole.OPERATOR_0);

            string[] memory directives2 = new string[](1);
            directives2[0] = "Perform weekly audits";

            data.agents[2] = IDAOAgent.AgentInfo({
                api: api2,
                roles: roles2,
                name: "Auditor Bot",
                directives: directives2,
                image: "",
                telegram: ""
            });

            // Agent 3: almost same to Agent 2
            data.agents[3] = IDAOAgent.AgentInfo({
                api: api2,
                roles: roles2,
                name: "Auditor Bot 2",
                directives: directives2,
                image: "",
                telegram: ""
            });
        }

        // ---------------- Dao params
        data.params = ITokenomics.DaoParameters({
            vePeriod: uint32(180),
            pvpFee: uint16(25),
            minPower: uint(100 ether),
            ttBribe: uint16(20000),
            recoveryShare: uint16(10000),
            proposalThreshold: uint(5000)
        });

        { // ---------------- Tokenomics
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
            funding[0] = ITokenomics.Funding({
                fundingType: ITokenomics.FundingType.SEED_0,
                start: uint64(1650000000),
                end: uint64(1650000000 + 30 days),
                minRaise: uint(1 ether),
                maxRaise: uint(100 ether),
                raised: uint(10 ether),
                claim: uint(0)
            });

            ITokenomics.Vesting[] memory vest = new ITokenomics.Vesting[](2);
            vest[0] = ITokenomics.Vesting({
                name: "Founders",
                description: "Founders allocation",
                allocation: uint(10 ether),
                start: uint64(1650000000),
                end: uint64(1650000000 + 365 days)
            });
            vest[1] = ITokenomics.Vesting({
                name: "Team",
                description: "Team allocation",
                allocation: uint(5 ether),
                start: uint64(1650000000 + 30 days),
                end: uint64(1650000000 + 730 days)
            });

            data.tokenomics = ITokenomics.Tokenomics({
                funding: funding,
                initialChain: uint256(1),
                vesting: vest
            });
        }

        return data;
    }

    function _assertDaoEqual(ITokenomics.DaoData memory expected, ITokenomics.DaoData memory actual) internal pure {
        // basic fields
        assertEq(uint256(uint8(expected.phase)), uint256(uint8(actual.phase)), "phase");
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
            assertEq(uint256(uint8(expected.activity[i])), uint256(uint8(actual.activity[i])), "activity[i]");
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
        assertEq(expected.deployments.vesting, actual.deployments.vesting, "deploy.vesting");
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
            assertEq(uint256(uint8(eu.status)), uint256(uint8(au.status)), "unit.status");
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

            assertEq(uint256(uint8(ef.fundingType)), uint256(uint8(af.fundingType)), "funding.fundingType");
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