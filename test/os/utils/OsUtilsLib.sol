// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol"; // todo upgradable
import {IOS, OS} from "../../../src/os/OS.sol";
import {OsLib} from "../../../src/os/libs/OsLib.sol";
import {IDAOUnit, IDAOAgent, ITokenomics} from "../../../src/interfaces/ITokenomics.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IControllable2} from "../../../src/interfaces/IControllable2.sol";
import {Proxy} from "../../../src/core/proxy/Proxy.sol";
import {Token} from "../../../src/tokenomics/Token.sol";
import {MockERC20} from "../../../src/test/MockERC20.sol";

library OsUtilsLib {
    uint64 internal constant ADMIN_ROLE = 1;
    uint64 internal constant MINTER_ROLE = 2;

    function createOsInstance(Vm vm, address multisig) public returns (IOS) {
        AccessManager accessManager = new AccessManager(multisig);

        address logic = address(new OS());
        Proxy proxy = new Proxy();
        proxy.initProxy(address(logic));
        IControllable2(address(proxy)).initialize(address(accessManager));

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
        funding[0] = generateSeedFunding();

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = generateDaoParams(365, 100);
        os.createDAO(daoName, daoSymbol, activity, params, funding);

        return os.getDAO(daoSymbol);
    }

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

        // Prepare and set OS chain settings using the IOS.OsChainSettings struct
        vm.prank(multisig);
        os.setChainSettings(IOS.OsChainSettings({exchangeAsset: address(usdc)}));
    }

    /// @notice Generate a seed funding with sensible defaults relative to current block timestamp.
    /// @return A populated ITokenomics.Funding struct ready to be passed to createDAO/updateFunding.
    function generateSeedFunding() public view returns (ITokenomics.Funding memory) {
        // Defaults: delaySec = 30 days, duration = 90 days, minRaise = 10_000, maxRaise = 100_000
        uint64 delaySec = uint64(30 days);
        uint64 duration = uint64(3 * 30 days);

        uint64 start = uint64(block.timestamp + delaySec);
        uint64 end = uint64(block.timestamp + delaySec + duration);

        return ITokenomics.Funding({
            fundingType: ITokenomics.FundingType.SEED_0,
            start: start,
            end: end,
            minRaise: 10000,
            maxRaise: 100000,
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

    function setupSeedToken(Vm vm, IOS os, address multisig, address seedToken) public {
        AccessManager accessManager = AccessManager(IControllable2(address(os)).authority());
        // set up multisig as operator for all restricted functions
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(Token.mint.selector);
        // todo selectors[1] = bytes4(Token.burn.selector);
        // todo selectors[2] = bytes4(Token.burnFrom.selector);

        vm.prank(multisig);
        accessManager.setTargetFunctionRole(seedToken, selectors, MINTER_ROLE);

        vm.prank(multisig);
        accessManager.grantRole(MINTER_ROLE, address(os), 0);
    }
}
