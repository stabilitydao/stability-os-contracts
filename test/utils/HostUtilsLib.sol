// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IHost, Host} from "../../src/Host.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";
import {IDAOMetadata} from "../../src/interfaces/IDAOMetadata.sol";
import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {IHostBridge} from "../../src/interfaces/IHostBridge.sol";
import {Proxy} from "../../src/base/Proxy.sol";
import {SeedToken} from "../../src/tokenomics/SeedToken.sol";
import {TgeToken} from "../../src/tokenomics/TgeToken.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {AccessRolesLib} from "../../src/libs/AccessRolesLib.sol";
import {MockOsBridge} from "../mocks/MockOsBridge.sol";
import {BridgeTestLib} from "./BridgeTestLib.sol";
import {IHostProxyFactory} from "../../src/interfaces/IHostProxyFactory.sol";
import {HostProxyFactory} from "../../src/HostProxyFactory.sol";

abstract contract HostUtilsLib {
    uint64 internal constant ADMIN_ROLE = AccessRolesLib.OS_ADMIN;
    uint64 internal constant MINTER_ROLE = AccessRolesLib.OS_TOKEN_MINTER;

    uint64 internal constant DEFAULT_SEED_DELAY = 30 days;
    uint64 internal constant DEFAULT_SEED_DURATION = 90 days;
    uint internal constant DEFAULT_SEED_MIN_RAISE = 10_000e18;
    uint internal constant DEFAULT_SEED_MAX_RAISE = 100_000e18;

    uint internal constant INITIAL_OS_ETHER_BALANCE = 100 ether;

    //region ----------------------------- Create OS and DAO instances
    function createHostInstance(Vm vm, address multisig, IAccessManager accessManager) public returns (IHost) {
        IHost.HostInitPayload memory init;
        return createHostInstance(vm, multisig, accessManager, init);
    }

    function createHostInstance(
        Vm vm,
        address multisig,
        IAccessManager accessManager,
        IHost.HostInitPayload memory init_
    ) public returns (IHost) {
        IHost host;
        {
            address logic = address(new Host());
            Proxy proxy = new Proxy();
            proxy.initProxy(address(logic));
            IHosted(address(proxy)).initialize(address(accessManager), abi.encode(init_));

            host = IHost(address(proxy));
        }

        // ---------------------- set up multisig as operator for all restricted functions of host
        {
            bytes4[] memory selectors = new bytes4[](5);
            selectors[0] = bytes4(Host.addLiveDAO.selector);
            selectors[1] = bytes4(Host.receiveVotingResults.selector);
            selectors[2] = bytes4(Host.refundFor.selector);
            selectors[3] = bytes4(Host.setSettings.selector);
            selectors[4] = bytes4(Host.setChainSettings.selector);

            vm.prank(multisig);
            accessManager.setTargetFunctionRole(address(host), selectors, ADMIN_ROLE);

            vm.prank(multisig);
            accessManager.grantRole(ADMIN_ROLE, multisig, 0);
        }

        // ---------------------- set up host factory
        IHostProxyFactory factory;
        {
            // ---------------------- create host factory
            address logic = address(new HostProxyFactory());
            Proxy proxy = new Proxy();
            proxy.initProxy(address(logic));
            IHosted(address(proxy)).initialize(address(accessManager), "");

            factory = IHostProxyFactory(address(proxy));

            // ---------------------- set up access to the host factory
            bytes4[] memory selectors = new bytes4[](2);
            selectors[0] = bytes4(IHostProxyFactory.setSeedTokenImplementation.selector);
            selectors[1] = bytes4(IHostProxyFactory.setTgeTokenImplementation.selector);

            vm.prank(multisig);
            accessManager.setTargetFunctionRole(address(factory), selectors, AccessRolesLib.HOST_PROXY_FACTORY_ADMIN);

            selectors = new bytes4[](2);
            selectors[0] = bytes4(IHostProxyFactory.deploySeedToken.selector);
            selectors[1] = bytes4(IHostProxyFactory.deployTgeToken.selector);

            vm.prank(multisig);
            accessManager.setTargetFunctionRole(address(factory), selectors, AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER);

            vm.prank(multisig);
            accessManager.grantRole(AccessRolesLib.HOST_PROXY_FACTORY_ADMIN, multisig, 0);

            vm.prank(multisig);
            accessManager.grantRole(AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER, address(host), 0);

            // ---------------------- set implementations
            vm.startPrank(multisig);
            factory.setSeedTokenImplementation(address(new SeedToken()));
            factory.setTgeTokenImplementation(address(new TgeToken()));
            vm.stopPrank();
        }

        // ---------------------- set host settings
        setHostSettings(vm, host, multisig);

        setChainSettings(vm, host, multisig, factory);

        return IHost(address(host));
    }

    function createDaoInstance(
        IHost os,
        string memory daoSymbol,
        string memory daoName
    ) public returns (IDAOData.DaoData memory) {
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

    function createAliensDao(Vm vm, IHost os_) public returns (IDAOData.DaoData memory) {
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = HostUtilsLib.generateSeedFunding(
            DEFAULT_SEED_DELAY, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
        );

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](2);
        activity[0] = ITokenomics.Activity.BUILDER_3;
        activity[1] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = HostUtilsLib.generateDaoParams(365, 100);

        return _createDao(vm, os_, "Aliens Community", "ALIENS", funding, activity, params);
    }

    function createApesDao(Vm vm, IHost os_) public returns (IDAOData.DaoData memory) {
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = HostUtilsLib.generateSeedFunding(
            7 days, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
        );

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = HostUtilsLib.generateDaoParams(30, 90);

        return _createDao(vm, os_, "Apes Syndicate", "APES", funding, activity, params);
    }

    function createDaoMachines(Vm vm, IHost os_) public returns (IDAOData.DaoData memory) {
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](2);
        funding[0] = HostUtilsLib.generateSeedFunding(
            7 days, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
        );
        funding[1] = HostUtilsLib.generateTGEFunding();

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.MEV_SEARCHER_2;

        ITokenomics.DaoParameters memory params = HostUtilsLib.generateDaoParams(14, 99);

        return _createDao(vm, os_, "Machines Cartel", "MACHINE", funding, activity, params);
    }

    function _createDao(
        Vm vm,
        IHost os_,
        string memory name_,
        string memory daoSymbol_,
        ITokenomics.Funding[] memory funding,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params
    ) internal returns (IDAOData.DaoData memory) {
        // user should pay for cross-chain messages
        uint value = os_.quoteCreateDAO(daoSymbol_);
        vm.deal(address(this), value);

        os_.createDAO{value: value}(name_, daoSymbol_, activity, params, funding);

        return os_.getDAO(daoSymbol_);
    }

    //endregion ----------------------------- Create OS and DAO instances

    //region ----------------------------- Settings
    function setHostSettings(Vm vm, IHost host_, address multisig) public {
        // Prepare and set OS settings using the IHost.OsSettings struct
        vm.prank(multisig);
        host_.setSettings(
            IHost.HostSettings({
                priceDao: 1000,
                priceUnit: 0, // todo implement not zero prices, 1000,
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

    function setChainSettings(Vm vm, IHost host_, address multisig, IHostProxyFactory factory_) public {
        MockERC20 usdc = new MockERC20();
        usdc.init("USD Coin", "USDC", 6);

        MockOsBridge bridge = new MockOsBridge();

        // Prepare and set OS chain settings using the IHost.OsChainSettings struct
        vm.prank(multisig);
        host_.setChainSettings(
            IHost.HostChainSettings({
                exchangeAsset: address(usdc), hostBridge: address(bridge), hostFactory: address(factory_)
            })
        );
    }

    function setupSeedToken(Vm vm, IHost os, address multisig, address seedToken) public {
        IAccessManager accessManager = IAccessManager(IHosted(address(os)).authority());

        // set up OS as operator for all restricted functions
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(SeedToken.mint.selector);
        selectors[1] = bytes4(SeedToken.refund.selector);

        vm.prank(multisig);
        accessManager.setTargetFunctionRole(seedToken, selectors, MINTER_ROLE);

        vm.prank(multisig);
        accessManager.grantRole(MINTER_ROLE, address(os), 0);
    }

    function setupTgeToken(Vm vm, IHost os, address multisig, address tgeToken) public {
        IAccessManager accessManager = IAccessManager(IHosted(address(os)).authority());

        // set up OS as operator for all restricted functions
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(TgeToken.mint.selector);
        selectors[1] = bytes4(TgeToken.refund.selector);

        vm.prank(multisig);
        accessManager.setTargetFunctionRole(tgeToken, selectors, MINTER_ROLE);

        vm.prank(multisig);
        accessManager.grantRole(MINTER_ROLE, address(os), 0);
    }

    function setupHostBridgeAndHostFactory(
        Vm vm,
        IHost os,
        BridgeTestLib.ChainConfig memory chain,
        BridgeTestLib.ChainConfig memory otherChain1,
        BridgeTestLib.ChainConfig memory otherChain2
    ) public {
        // -------------------- put some ether on OS contract to send cross-chain messages
        vm.deal(address(os), INITIAL_OS_ETHER_BALANCE);

        // -------------------- set HostBridge inside host
        IHost.HostChainSettings memory config = os.getChainSettings();

        vm.prank(chain.multisig);
        os.setChainSettings(
            IHost.HostChainSettings({
                exchangeAsset: config.exchangeAsset, hostBridge: chain.hostBridge, hostFactory: chain.hostFactory
            })
        );

        // -------------------- set os and endpoints inside osBridge
        vm.prank(chain.multisig);
        IHostBridge(chain.hostBridge).setHost(address(os));

        uint32[] memory endpoints = new uint32[](2);
        endpoints[0] = otherChain1.endpointId;
        endpoints[1] = otherChain2.endpointId;

        vm.prank(chain.multisig);
        IHostBridge(chain.hostBridge).addEndpoint(endpoints);

        IAccessManager accessManager = IAccessManager(IHosted(address(os)).authority());

        // ----------------------------- Allow OS to call OSBridge.sendMessageToAllChains
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(IHostBridge.sendMessageToAllChains.selector);

            vm.prank(chain.multisig);
            accessManager.setTargetFunctionRole(chain.hostBridge, selectors, AccessRolesLib.OS_BRIDGE_USER);

            vm.prank(chain.multisig);
            accessManager.grantRole(AccessRolesLib.OS_BRIDGE_USER, address(os), 0);
        }

        // ----------------------------- Allow OSBridge to call OS.receiveCrossChainMessage
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(IHost.onReceiveCrossChainMessage.selector);

            vm.prank(chain.multisig);
            accessManager.setTargetFunctionRole(address(os), selectors, AccessRolesLib.OS_BRIDGE);

            vm.prank(chain.multisig);
            accessManager.grantRole(AccessRolesLib.OS_BRIDGE, address(chain.hostBridge), 0);
        }

        // ----------------------------- Set gas limits
        vm.prank(chain.multisig);
        IHostBridge(chain.hostBridge).setGasLimit(uint(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0), 70_000);

        vm.prank(chain.multisig);
        IHostBridge(chain.hostBridge).setGasLimit(uint(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1), 90_000);
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

    function createTestDaoData() public pure returns (IDAOData.DaoDataInput memory data) {
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

        // ---------------- Create 3 units
        data.units = new IDAOData.UnitDataInput[](3);
        data.unitsMetaData = new IDAOMetadata.UnitMetaData[](3);

        { // Unit 0: one UI link, two API endpoints
            IDAOMetadata.UnitUiLink[] memory ui0 = new IDAOMetadata.UnitUiLink[](1);
            ui0[0] = IDAOMetadata.UnitUiLink({title: "Dashboard", href: "https://unit0.example/dashboard"});

            string[] memory api0 = new string[](2);
            api0[0] = "https://api.unit0.example/v1/status";
            api0[1] = "https://api.unit0.example/v1/metrics";

            data.unitsMetaData[0] = IDAOMetadata.UnitMetaData({
                name: "Protocol A",
                status: IDAOMetadata.UnitStatus.RESEARCH_0,
                unitType: uint16(IDAOMetadata.UnitType.DEFI_PROTOCOL_1),
                revenueShare: 20000,
                emoji: "zzz",
                ui: ui0,
                api: api0
            });
            data.units[0] = IDAOData.UnitDataInput({unitId: "defi:protocolA", developerUid: ""});
        }

        { // Unit 1: two UI links, one API endpoint
            IDAOMetadata.UnitUiLink[] memory ui1 = new IDAOMetadata.UnitUiLink[](2);
            ui1[0] = IDAOMetadata.UnitUiLink({title: "App", href: "https://unit1.example/app"});
            ui1[1] = IDAOMetadata.UnitUiLink({title: "Docs", href: "https://unit1.example/docs"});

            string[] memory api1 = new string[](1);
            api1[0] = "https://api.unit1.example/";

            data.unitsMetaData[1] = IDAOMetadata.UnitMetaData({
                name: "Service X",
                status: IDAOMetadata.UnitStatus.BUILDING_1,
                unitType: uint16(IDAOMetadata.UnitType.SAAS_2),
                revenueShare: 50000,
                emoji: "aaa",
                ui: ui1,
                api: api1
            });
            data.units[1] = IDAOData.UnitDataInput({unitId: "saas:serviceX", developerUid: ""});
        }

        { // Unit 2: no UI links, empty api array
            IDAOMetadata.UnitUiLink[] memory ui2 = new IDAOMetadata.UnitUiLink[](0);
            string[] memory api2 = new string[](0);

            data.unitsMetaData[2] = IDAOMetadata.UnitMetaData({
                name: "MEV Bot Z",
                status: IDAOMetadata.UnitStatus.LIVE_2,
                unitType: uint16(IDAOMetadata.UnitType.MEV_3),
                revenueShare: 80000,
                emoji: "aaaaaaaa",
                ui: ui2,
                api: api2
            });
            data.units[2] = IDAOData.UnitDataInput({unitId: "mev:botZ", developerUid: ""});
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

            data.funding = funding;
            data.vesting = vest;
        }

        return data;
    }

    //endregion ----------------------------- Funding, DaoParams, Vesting

    //region ----------------------------- Print
    function printDaoData(IDAOData.DaoData memory data) public pure {
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
            console.log(i, data.units[i].unitId);
        }
    }

    function printTasks(IHost.Task[] memory tasks) internal pure {
        for (uint i; i < tasks.length; i++) {
            console.log(tasks[i].name);
        }
    }

    //endregion ----------------------------- Print

    //region ----------------------------- Utils
    function getFundingIndex(
        IDAOData.DaoData memory data,
        ITokenomics.FundingType fType
    ) public pure returns (uint index) {
        for (uint i; i < data.funding.length; i++) {
            if (data.funding[i].fundingType == fType) {
                return i;
            }
        }
        return uint(type(uint).max);
    }

    function getLastProposalId(IHost os, string memory daoSymbol) public view returns (bytes32) {
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
