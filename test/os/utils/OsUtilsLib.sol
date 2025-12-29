// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IOS, OS} from "../../../src/os/OS.sol";
import {IDAOUnit, IDAOAgent, ITokenomics} from "../../../src/interfaces/ITokenomics.sol";
import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IControllable2} from "../../../src/interfaces/IControllable2.sol";
import {IOSBridge} from "../../../src/interfaces/IOSBridge.sol";
import {Proxy} from "../../../src/core/proxy/Proxy.sol";
import {SeedToken} from "../../../src/tokenomics/SeedToken.sol";
import {TgeToken} from "../../../src/tokenomics/TgeToken.sol";
import {MockERC20} from "../../../src/test/MockERC20.sol";
import {AccessRolesLib} from "../../../src/core/libs/AccessRolesLib.sol";
import {MockOsBridge} from "../../../src/test/MockOsBridge.sol";
import {BridgeTestLib} from "./BridgeTestLib.sol";

abstract contract OsUtilsLib {
    uint64 internal constant ADMIN_ROLE = AccessRolesLib.OS_ADMIN;
    uint64 internal constant MINTER_ROLE = AccessRolesLib.OS_TOKEN_MINTER;

    uint64 internal constant DEFAULT_SEED_DELAY = 30 days;
    uint64 internal constant DEFAULT_SEED_DURATION = 90 days;
    uint internal constant DEFAULT_SEED_MIN_RAISE = 10_000e18;
    uint internal constant DEFAULT_SEED_MAX_RAISE = 100_000e18;

    //region ----------------------------- Create OS and DAO instances
    function createOsInstance(Vm vm, address multisig, IAccessManager accessManager) public returns (IOS) {
        IOS.OsInitPayload memory init;
        return createOsInstance(vm, multisig, accessManager, init);
    }

    function createOsInstance(Vm vm, address multisig, IAccessManager accessManager, IOS.OsInitPayload memory init_) public returns (IOS) {

        address logic = address(new OS());
        Proxy proxy = new Proxy();
        proxy.initProxy(address(logic));
        IControllable2(address(proxy)).initialize(address(accessManager), abi.encode(init_));

        IOS os = IOS(address(proxy));

        // set up multisig as operator for all restricted functions
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = bytes4(OS.addLiveDAO.selector);
        selectors[1] = bytes4(OS.receiveVotingResults.selector);
        selectors[2] = bytes4(OS.refundFor.selector);
        selectors[3] = bytes4(OS.setSettings.selector);
        selectors[4] = bytes4(OS.setChainSettings.selector);

        vm.prank(multisig);
        accessManager.setTargetFunctionRole(address(os), selectors, ADMIN_ROLE);

        vm.prank(multisig);
        accessManager.grantRole(ADMIN_ROLE, multisig, 0);

        setOsSettings(vm, os, multisig);

        setChainSettings(vm, os, multisig);

        return IOS(address(os));
    }

    function createDaoInstance(
        IOS os,
        string memory daoSymbol,
        string memory daoName
    ) public returns (ITokenomics.DaoData memory) {
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = generateSeedFunding(
            DEFAULT_SEED_DELAY, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
        );

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = generateDaoParams(365, 100);
        os.createDAO(daoName, daoSymbol, activity, params, funding);

        return os.getDAO(daoSymbol);
    }

    function createAliensDao(IOS os_) public returns (ITokenomics.DaoData memory) {
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = OsUtilsLib.generateSeedFunding(
            DEFAULT_SEED_DELAY, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
        );

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](2);
        activity[0] = ITokenomics.Activity.BUILDER_3;
        activity[1] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = OsUtilsLib.generateDaoParams(365, 100);

        os_.createDAO("Aliens Community", "ALIENS", activity, params, funding);

        return os_.getDAO("ALIENS");
    }

    function createApesDao(IOS os_) public returns (ITokenomics.DaoData memory) {
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = OsUtilsLib.generateSeedFunding(
            7 days, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
        );

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = OsUtilsLib.generateDaoParams(30, 90);

        os_.createDAO("Apes Syndicate", "APES", activity, params, funding);

        return os_.getDAO("APES");
    }

    function createDaoMachines(IOS os_) public returns (ITokenomics.DaoData memory) {
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](2);
        funding[0] = OsUtilsLib.generateSeedFunding(
            7 days, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
        );
        funding[1] = OsUtilsLib.generateTGEFunding();

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.MEV_SEARCHER_2;

        ITokenomics.DaoParameters memory params = OsUtilsLib.generateDaoParams(14, 99);

        os_.createDAO("Machines Cartel", "MACHINE", activity, params, funding);

        return os_.getDAO("MACHINE");
    }

    //endregion ----------------------------- Create OS and DAO instances

    //region ----------------------------- Settings
    function setOsSettings(Vm vm, IOS os, address multisig) public {
        // Prepare and set OS settings using the IOS.OsSettings struct
        vm.prank(multisig);
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
                minAbsorbOfferUsd: 50000,
                maxSeedStartDelay: 7 days
            })
        );
    }

    function setChainSettings(Vm vm, IOS os, address multisig) public {
        MockERC20 usdc = new MockERC20();
        usdc.init("USD Coin", "USDC", 6);

        MockOsBridge bridge = new MockOsBridge();

        // Prepare and set OS chain settings using the IOS.OsChainSettings struct
        vm.prank(multisig);
        os.setChainSettings(IOS.OsChainSettings({exchangeAsset: address(usdc), osBridge: address(bridge)}));
    }

    function setupSeedToken(Vm vm, IOS os, address multisig, address seedToken) public {
        IAccessManager accessManager = IAccessManager(IControllable2(address(os)).authority());

        // set up OS as operator for all restricted functions
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(SeedToken.mint.selector);
        selectors[1] = bytes4(SeedToken.refund.selector);

        vm.prank(multisig);
        accessManager.setTargetFunctionRole(seedToken, selectors, MINTER_ROLE);

        vm.prank(multisig);
        accessManager.grantRole(MINTER_ROLE, address(os), 0);
    }

    function setupTgeToken(Vm vm, IOS os, address multisig, address tgeToken) public {
        IAccessManager accessManager = IAccessManager(IControllable2(address(os)).authority());

        // set up OS as operator for all restricted functions
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(TgeToken.mint.selector);
        selectors[1] = bytes4(TgeToken.refund.selector);

        vm.prank(multisig);
        accessManager.setTargetFunctionRole(tgeToken, selectors, MINTER_ROLE);

        vm.prank(multisig);
        accessManager.grantRole(MINTER_ROLE, address(os), 0);
    }

    function setupOsBridge(Vm vm, IOS os, BridgeTestLib.ChainConfig memory chain) public {
        IOS.OsChainSettings memory config = os.getChainSettings();

        vm.prank(chain.multisig);
        os.setChainSettings(
            IOS.OsChainSettings({
                exchangeAsset: config.exchangeAsset,
                osBridge: chain.osBridge
            })
        );

        IAccessManager accessManager = IAccessManager(IControllable2(address(os)).authority());

        // ----------------------------- Allow OS to call OSBridge.sendMessageToAllChains
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(IOSBridge.sendMessageToAllChains.selector);

            vm.prank(chain.multisig);
            accessManager.setTargetFunctionRole(chain.osBridge, selectors, AccessRolesLib.OS_BRIDGE_USER);

            vm.prank(chain.multisig);
            accessManager.grantRole(AccessRolesLib.OS_BRIDGE_USER, address(os), 0);
        }

        // ----------------------------- Allow OSBridge to call OS.receiveCrossChainMessage
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(IOS.onReceiveCrossChainMessage.selector);

            vm.prank(chain.multisig);
            accessManager.setTargetFunctionRole(address(os), selectors, AccessRolesLib.OS_BRIDGE);

            vm.prank(chain.multisig);
            accessManager.grantRole(AccessRolesLib.OS_BRIDGE, address(chain.osBridge), 0);
        }
    }

    function setupOsBridgeGasLimits(Vm vm, BridgeTestLib.ChainConfig memory src) public {
        vm.selectFork(src.fork);

        vm.prank(src.multisig);
        IOSBridge(src.osBridge).setGasLimit(uint(IOS.CrossChainMessages.NEW_DAO_SYMBOL_0), 70_000);

        vm.prank(src.multisig);
        IOSBridge(src.osBridge).setGasLimit(uint(IOS.CrossChainMessages.DAO_RENAME_SYMBOL_1), 90_000);
    }
    //endregion ----------------------------- Settings

    //region ----------------------------- Funding, DaoParams, Vesting
    /// @notice Generate a seed funding with sensible defaults relative to current block timestamp.
    /// @return A populated ITokenomics.Funding struct ready to be passed to createDAO/updateFunding.
    function generateSeedFunding(
        uint delaySec,
        uint duration,
        uint minRaise,
        uint maxRaise
    ) public view returns (ITokenomics.Funding memory) {
        return ITokenomics.Funding({
            fundingType: ITokenomics.FundingType.SEED_0,
            start: uint64(block.timestamp + delaySec),
            end: uint64(block.timestamp + delaySec + duration),
            minRaise: minRaise,
            maxRaise: maxRaise,
            raised: 0,
            claim: 0
        });
    }

    function generateTGEFunding() public view returns (ITokenomics.Funding memory) {
        uint64 _after = 30 * 6 days;
        uint64 duration = 7 days;
        uint minRaise = 100_000e18; // exchange asset
        uint maxRaise = 500_000e18; // ex change asset

        return ITokenomics.Funding({
            fundingType: ITokenomics.FundingType.TGE_1,
            start: uint64(block.timestamp + _after),
            end: uint64(block.timestamp + _after + duration),
            minRaise: minRaise,
            maxRaise: maxRaise,
            raised: 0,
            claim: 0
        });
    }

    function generateDaoParams(
        uint32 vePeriod_,
        uint16 pvpFee_
    ) public pure returns (ITokenomics.DaoParameters memory) {
        return ITokenomics.DaoParameters({
            vePeriod: vePeriod_, pvpFee: pvpFee_, minPower: 0, ttBribe: 0, recoveryShare: 0, proposalThreshold: 0
        });
    }

    function generateVesting(string memory name, uint tgeEnd) public pure returns (ITokenomics.Vesting memory) {
        uint64 cliff = 180 days;
        uint64 duration = 365 days;
        uint64 allocation = 100;
        return ITokenomics.Vesting({
            name: name,
            description: "Vesting for testing",
            start: uint64(tgeEnd + cliff),
            end: uint64(tgeEnd + cliff + duration),
            allocation: allocation
        });
    }

    function createTestDaoData() public pure returns (ITokenomics.DaoData memory data) {
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
        address[] memory vestings = new address[](2);
        vestings[0] = address(0x5001);
        vestings[1] = address(0x5002);

        data.deployments = ITokenomics.DaoDeploymentInfo({
            seedToken: address(0x1001),
            tgeToken: address(0x1002),
            token: address(0x1003),
            xToken: address(0x1004),
            staking: address(0x2001),
            daoToken: address(0x2002),
            revenueRouter: address(0x2003),
            recovery: address(0x2004),
            vesting: vestings,
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
            ui0[0] = IDAOUnit.UnitUiLink({title: "Dashboard", href: "https://unit0.example/dashboard"});

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
            ui1[0] = IDAOUnit.UnitUiLink({title: "App", href: "https://unit1.example/app"});
            ui1[1] = IDAOUnit.UnitUiLink({title: "Docs", href: "https://unit1.example/docs"});

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
                api: api2, roles: roles2, name: "Auditor Bot", directives: directives2, image: "", telegram: ""
            });

            // Agent 3: almost same to Agent 2
            data.agents[3] = IDAOAgent.AgentInfo({
                api: api2, roles: roles2, name: "Auditor Bot 2", directives: directives2, image: "", telegram: ""
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

            data.tokenomics = ITokenomics.Tokenomics({funding: funding, initialChain: uint(1), vesting: vest});
        }

        return data;
    }
    //endregion ----------------------------- Funding, DaoParams, Vesting

    //region ----------------------------- Print
    function printDaoData(ITokenomics.DaoData memory data) public pure {
        console.log("DAO Symbol:", data.symbol);
        console.log("DAO Name:", data.name);
        console.log("Deployer:", data.deployer);
        console.log("Phase:", uint8(data.phase));

        console.log("Deployments:");
        console.log("  Seed Token:", data.deployments.seedToken);
        console.log("  TGE Token:", data.deployments.tgeToken);
        console.log("  Token:", data.deployments.token);
        console.log("  xToken:", data.deployments.xToken);
        console.log("  Staking:", data.deployments.staking);
        console.log("  DAO Token:", data.deployments.daoToken);
        console.log("  Revenue Router:", data.deployments.revenueRouter);
        console.log("  Recovery:", data.deployments.recovery);
        console.log("  Token Bridge:", data.deployments.tokenBridge);
        console.log("  xToken Bridge:", data.deployments.xTokenBridge);
        console.log("  DAO Token Bridge:", data.deployments.daoTokenBridge);
        for (uint i = 0; i < data.deployments.vesting.length; i++) {
            console.log(i, data.deployments.vesting[i]);
        }

        console.log("Images:");
        console.log("  Seed Token:", data.images.seedToken);
        console.log("  TGE Token:", data.images.tgeToken);
        console.log("  Token:", data.images.token);
        console.log("  xToken:", data.images.xToken);
        console.log("  DAO Token:", data.images.daoToken);

        console.log("Socials:");
        for (uint i = 0; i < data.socials.length; i++) {
            console.log(i, data.socials[i]);
        }

        console.log("Units:");
        for (uint i = 0; i < data.units.length; i++) {
            console.log(i, data.units[i].unitId, data.units[i].name);
        }

        console.log("Agents:");
        for (uint i = 0; i < data.agents.length; i++) {
            console.log(i, data.agents[i].name);
        }
    }

    function printTasks(IOS.Task[] memory tasks) internal pure {
        for (uint i; i < tasks.length; i++) {
            console.log(tasks[i].name);
        }
    }
    //endregion ----------------------------- Print

    //region ----------------------------- Utils
    function getFundingIndex(
        ITokenomics.DaoData memory data,
        ITokenomics.FundingType fType
    ) public pure returns (uint index) {
        for (uint i; i < data.tokenomics.funding.length; i++) {
            if (data.tokenomics.funding[i].fundingType == fType) {
                return i;
            }
        }
        return uint(type(uint).max);
    }

    function getLastProposalId(IOS os, string memory daoSymbol) public view returns (bytes32) {
        uint len = os.proposalsLength(daoSymbol);
        require(len != 0, "No proposals found");
        bytes32[] memory proposalIds = os.proposalIds(daoSymbol, len - 1, 1);
        return proposalIds[0];
    }

    function test() public {
        // empty function to exclude the library from the coverage
    }
    //endregion ----------------------------- Utils
}
