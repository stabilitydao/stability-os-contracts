// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Vm} from "forge-std/Test.sol";
// import {console} from "forge-std/console.sol";
import {AccessRolesLib} from "../../src/libs/AccessRolesLib.sol";
import {Authority} from "../../src/Authority.sol";
import {DataReader} from "../../src/DataReader.sol";
import {HostCodec} from "../../src/HostCodec.sol";
import {HostEncodingLib} from "../../src/libs/HostEncodingLib.sol";
import {Host} from "../../src/Host.sol";
import {MockHostBridge} from "../mocks/MockHostBridge.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {SampleDataLib} from "./SampleDataLib.sol";
import {SeedToken} from "../../src/tokenomics/SeedToken.sol";
import {TgeToken} from "../../src/tokenomics/TgeToken.sol";
import {HostSetupUtils} from "../scenario/access/HostSetupUtils.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {IDataReader} from "../../src/interfaces/IDataReader.sol";
import {IHostCodec} from "../../src/interfaces/IHostCodec.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";
import {EventUtilsLib} from "./EventUtilsLib.sol";

library HostUtilsLib {
    uint64 internal constant ADMIN_ROLE = AccessRolesLib.HOST_ADMIN;
    uint64 internal constant MINTER_ROLE = AccessRolesLib.HOST_TOKEN_MINTER;

    uint64 internal constant DEFAULT_SEED_DELAY = 30 days;
    uint64 internal constant DEFAULT_SEED_DURATION = 90 days;
    uint internal constant DEFAULT_SEED_MIN_RAISE = 10_000e18;
    uint internal constant DEFAULT_SEED_MAX_RAISE = 100_000e18;

    function deployHost(
        Vm vm,
        address multisig,
        IHost.HostInitPayload memory hostPayload
    ) internal returns (IAuthority, IHost) {
        // ------------------- deploy proxy factory
        vm.prank(multisig);
        ProxyFactory proxyFactory = new ProxyFactory();

        // ------------------- deploy authority
        address hostPredicted = proxyFactory.predictAddress("0x62436");
        Authority authority = new Authority(multisig, hostPredicted, address(proxyFactory));

        vm.prank(multisig);
        proxyFactory.setWhitelisted(address(authority), true);

        vm.prank(multisig);
        proxyFactory.setWhitelisted(hostPredicted, true);

        // ------------------- deploy host
        address logic = address(new Host());

        //        bytes[] memory calls = new bytes[](2);
        //
        //        // 1. create2NewProxy
        //        calls[0] = abi.encodeCall(
        //            AccessManager.execute,
        //            (
        //                address(proxyFactory),
        //                abi.encodeCall(IProxyFactory.create2NewProxy, ("0x62436", logic, ""))
        //            )
        //        );
        //
        //        // 2. initialize host
        //        calls[1] = abi.encodeCall(
        //            AccessManager.execute,
        //            (
        //                hostPredicted,
        //                abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(hostPayload)))
        //            )
        //        );
        //        vm.prank(multisig);
        //        authority.multicall(calls);

        vm.prank(multisig);
        authority.execute(
            address(proxyFactory),
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                ("0x62436", logic, abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(hostPayload))))
            )
        );

        return (IAuthority(authority), IHost(hostPredicted));
    }

    //region ----------------------------- Create HOST and DAO instances
    function createHostInstance(Vm vm, address multisig) internal returns (IHost) {
        IHost.HostInitPayload memory init;
        init.hostVersion = "1.0.0";
        return createHostInstance(vm, multisig, init);
    }

    function createHostInstance(Vm vm, address multisig, IHost.HostInitPayload memory init_) internal returns (IHost) {
        (IAuthority accessManager, IHost host) = deployHost(vm, multisig, init_);
        setupHostInstance(vm, multisig, accessManager, host);
        return IHost(address(host));
    }

    function createHostCodec(Vm vm, address multisig, IHost host) internal returns (IHostCodec) {
        IAuthority accessManager = IAuthority(IAccessManaged(address(host)).authority());

        {
            // ---------------------- set up access to the host factory
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(IHost.deployProxy.selector);

            vm.prank(multisig);
            accessManager.setTargetFunctionRole(address(host), selectors, AccessRolesLib.HOST_PROXY_FACTORY_ADMIN);

            vm.prank(multisig);
            accessManager.grantRole(AccessRolesLib.HOST_PROXY_FACTORY_ADMIN, multisig, 0);

            vm.prank(multisig);
            accessManager.grantRole(AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER, multisig, 0);
        }

        address logic = address(new HostCodec());
        vm.prank(multisig);
        return IHostCodec(address(host.deployProxy("0x1850878", logic, "")));
    }

    function setupHostInstance(Vm vm, address multisig, IAuthority accessManager, IHost host) internal {
        // ---------------------- set up multisig as operator for all restricted functions of host
        {
            bytes4[] memory selectors = new bytes4[](5);
            selectors[0] = bytes4(Host.updateByAdmin.selector);
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
        {
            // ---------------------- set up access to the host factory
            bytes4[] memory selectors = new bytes4[](2);
            selectors[0] = bytes4(IHost.setContractImplementation.selector);
            selectors[1] = bytes4(IHost.deployProxy.selector);

            vm.prank(multisig);
            accessManager.setTargetFunctionRole(address(host), selectors, AccessRolesLib.HOST_PROXY_FACTORY_ADMIN);

            vm.prank(multisig);
            accessManager.grantRole(AccessRolesLib.HOST_PROXY_FACTORY_ADMIN, multisig, 0);

            vm.prank(multisig);
            accessManager.grantRole(AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER, multisig, 0);

            // ---------------------- set implementations
            vm.startPrank(multisig);
            host.setContractImplementation(uint(IHost.ContractKinds.SEED_TOKEN_1), address(new SeedToken()));
            host.setContractImplementation(uint(IHost.ContractKinds.TGE_TOKEN_2), address(new TgeToken()));
            vm.stopPrank();
        }

        // ---------------------- set up data reader
        IDataReader dataReader;
        {
            address logic = address(new DataReader());
            vm.prank(multisig);
            dataReader = IDataReader(host.deployProxy("0x26313520", logic, ""));
        }

        // ---------------------- set host settings
        setHostSettings(vm, host, multisig);

        setChainSettings(vm, host, multisig, address(dataReader));

        {
            address exchangeAsset = host.getChainSettings().exchangeAsset;
            HostSetupUtils.whitelistAsset(vm, multisig, host, exchangeAsset);
        }
    }

    function createDaoInstance(
        IHost host,
        string memory symbol,
        string memory daoName
    ) public returns (IDAOData.DaoData memory) {
        IDAOData.Funding[] memory funding = new IDAOData.Funding[](1);
        funding[0] = generateSeedFunding(
            DEFAULT_SEED_DELAY, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
        );

        IDAOData.Activity[] memory activity = new IDAOData.Activity[](1);
        activity[0] = IDAOData.Activity.DEFI_PROTOCOL_OPERATOR_0;

        IDAOData.DaoParameters memory params = generateDaoParams(365, 100);
        host.createDAO(daoName, symbol, activity, params, funding);

        return IDataReader(host.getChainSettings().dataReader).getDAO(symbol);
    }

    function createAliensDao(Vm vm, IHost os_, string memory symbol) internal returns (IDAOData.DaoData memory) {
        IDAOData.Funding[] memory funding = new IDAOData.Funding[](1);
        funding[0] = generateSeedFunding(
            DEFAULT_SEED_DELAY, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE
        );

        IDAOData.Activity[] memory activity = new IDAOData.Activity[](2);
        activity[0] = IDAOData.Activity.BUILDER_3;
        activity[1] = IDAOData.Activity.DEFI_PROTOCOL_OPERATOR_0;

        IDAOData.DaoParameters memory params = generateDaoParams(365, 100);

        return _createDao(vm, os_, "Aliens Community", symbol, funding, activity, params);
    }

    function createApesDao(Vm vm, IHost os_) internal returns (IDAOData.DaoData memory) {
        IDAOData.Funding[] memory funding = new IDAOData.Funding[](1);
        funding[0] = generateSeedFunding(
            SampleDataLib.DEFAULT_MIN_INCEPTION_DURATION,
            DEFAULT_SEED_DURATION,
            DEFAULT_SEED_MIN_RAISE,
            DEFAULT_SEED_MAX_RAISE
        );

        IDAOData.Activity[] memory activity = new IDAOData.Activity[](1);
        activity[0] = IDAOData.Activity.DEFI_PROTOCOL_OPERATOR_0;

        IDAOData.DaoParameters memory params = generateDaoParams(30, 90);

        return _createDao(vm, os_, "Apes Syndicate", "APES", funding, activity, params);
    }

    function createDaoMachines(Vm vm, IHost os_) internal returns (IDAOData.DaoData memory) {
        IDAOData.Funding[] memory funding = new IDAOData.Funding[](2);
        funding[0] = generateSeedFunding(7 days, DEFAULT_SEED_DURATION, DEFAULT_SEED_MIN_RAISE, DEFAULT_SEED_MAX_RAISE);
        funding[1] = generateTGEFunding();

        IDAOData.Activity[] memory activity = new IDAOData.Activity[](1);
        activity[0] = IDAOData.Activity.MEV_SEARCHER_2;

        IDAOData.DaoParameters memory params = generateDaoParams(14, 99);

        return _createDao(vm, os_, "Machines Cartel", "MACHINE", funding, activity, params);
    }

    function _createDao(
        Vm vm,
        IHost host_,
        string memory name_,
        string memory symbol_,
        IDAOData.Funding[] memory funding,
        IDAOData.Activity[] memory activity,
        IDAOData.DaoParameters memory params
    ) internal returns (IDAOData.DaoData memory) {
        // user should pay for cross-chain messages
        uint value = host_.quoteCreateDAO(symbol_);
        vm.deal(address(this), value);

        host_.createDAO{value: value}(name_, symbol_, activity, params, funding);

        return IDataReader(host_.getChainSettings().dataReader).getDAO(symbol_);
    }

    //endregion ----------------------------- Create OS and DAO instances

    //region ----------------------------- Settings
    function setHostSettings(Vm vm, IHost host_, address multisig) internal {
        vm.startPrank(multisig);
        host_.setSettings(SampleDataLib.getHostSettings());
        vm.stopPrank();
    }

    function setChainSettings(Vm vm, IHost host_, address multisig, address dataReader) internal {
        MockHostBridge bridge = new MockHostBridge();

        vm.startPrank(multisig);
        host_.setChainSettings(SampleDataLib.getHostChainSettings(address(bridge), dataReader));
        vm.stopPrank();
    }

    //endregion ----------------------------- Settings

    //region ----------------------------- Funding, DaoParams, Vesting
    /// @notice Generate a seed funding with sensible defaults relative to current block timestamp.
    /// @return A populated IDAOData.Funding struct ready to be passed to createDAO/updateFunding.
    function generateSeedFunding(
        uint delaySec,
        uint duration,
        uint minRaise,
        uint maxRaise
    ) internal view returns (IDAOData.Funding memory) {
        return IDAOData.Funding({
            fundingType: IDAOData.FundingType.SEED_0,
            start: uint64(block.timestamp + delaySec),
            end: uint64(block.timestamp + delaySec + duration),
            minRaise: minRaise,
            maxRaise: maxRaise,
            raised: 0,
            claim: 0
        });
    }

    function generateTGEFunding() internal view returns (IDAOData.Funding memory) {
        uint64 _after = 30 * 6 days;
        uint64 duration = 7 days;
        uint minRaise = 100_000e18; // exchange asset
        uint maxRaise = 500_000e18; // ex change asset

        return IDAOData.Funding({
            fundingType: IDAOData.FundingType.TGE_1,
            start: uint64(block.timestamp + _after),
            end: uint64(block.timestamp + _after + duration),
            minRaise: minRaise,
            maxRaise: maxRaise,
            raised: 0,
            claim: uint64(block.timestamp + 1 days)
        });
    }

    function generateDaoParams(uint32 vePeriod_, uint16 pvpFee_) internal pure returns (IDAOData.DaoParameters memory) {
        return IDAOData.DaoParameters({
            vePeriod: vePeriod_,
            pvpFee: pvpFee_,
            minPower: 0,
            ttBribe: 0,
            recoveryShare: 0,
            proposalThreshold: 0,
            totalSupply: 1e9
        });
    }

    function generateVesting(string memory name, uint tgeEnd) internal pure returns (IDAOData.Vesting memory) {
        uint64 cliff = 180 days;
        uint64 duration = 365 days;
        uint32 allocation = 100;
        return IDAOData.Vesting({
            name: name,
            description: "Vesting for testing",
            start: uint64(tgeEnd + cliff),
            end: uint64(tgeEnd + cliff + duration),
            allocation: allocation
        });
    }

    function createTestDaoData() internal pure returns (IDAOData.DaoDataInput memory data) {
        // ---------------- base fields
        data.phase = IDAOData.LifecyclePhase.DEVELOPMENT_4;
        data.symbol = "TESTDAO";
        data.name = "Test DAO";
        data.deployer = address(0x123);

        // ---------------- socials
        data.socials = new string[](3);
        data.socials[0] = "https://twitter.com/testdao";
        data.socials[1] = "https://github.com/testdao";
        data.socials[2] = "https://discord.gg/testdao";

        // ---------------- activity
        data.activity = new IDAOData.Activity[](2);
        data.activity[0] = IDAOData.Activity.SAAS_OPERATOR_1;
        data.activity[1] = IDAOData.Activity.BUILDER_3;

        // ---------------- images
        data.images = SampleDataLib.getDaoImages();

        // ---------------- Deployments
        address[] memory vestings = new address[](2);
        vestings[0] = address(0x5001);
        vestings[1] = address(0x5002);

        data.deployments = IDAOData.DaoDeploymentInfo({
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
        (data.units, data.unitDataToEmit) = SampleDataLib.getUnitsThree();

        // ---------------- Dao params
        data.params = IDAOData.DaoParameters({
            vePeriod: uint32(180),
            pvpFee: uint16(25),
            minPower: uint(100 ether),
            ttBribe: uint16(20000),
            recoveryShare: uint16(10000),
            proposalThreshold: uint(5000),
            totalSupply: 1e9
        });

        { // ---------------- Tokenomics
            IDAOData.Funding[] memory funding = new IDAOData.Funding[](1);
            funding[0] = IDAOData.Funding({
                fundingType: IDAOData.FundingType.SEED_0,
                start: uint64(1650000000),
                end: uint64(1650000000 + 30 days),
                minRaise: uint(1 ether),
                maxRaise: uint(100 ether),
                raised: uint(10 ether),
                claim: uint64(0)
            });

            IDAOData.Vesting[] memory vest = new IDAOData.Vesting[](2);
            vest[0] = IDAOData.Vesting({
                name: "Founders",
                description: "Founders allocation",
                allocation: uint32(90_000),
                start: uint64(1650000000),
                end: uint64(1650000000 + 365 days)
            });
            vest[1] = IDAOData.Vesting({
                name: "Team",
                description: "Team allocation",
                allocation: uint32(80_000),
                start: uint64(1650000000 + 30 days),
                end: uint64(1650000000 + 730 days)
            });

            data.funding = funding;
            data.vesting = vest;
        }

        return data;
    }

    //endregion ----------------------------- Funding, DaoParams, Vesting

    //region ----------------------------- Utils
    function getFundingIndex(
        IDAOData.DaoData memory data,
        IDAOData.FundingType fType
    ) internal pure returns (uint index) {
        for (uint i; i < data.funding.length; i++) {
            if (data.funding[i].fundingType == fType) {
                return i;
            }
        }
        return uint(type(uint).max);
    }

    function getLastProposalId(IHost os, string memory symbol) internal view returns (bytes32) {
        uint len = os.proposalsLength(symbol);
        require(len != 0, "No proposals found");
        bytes32[] memory proposalIds = os.proposalIds(symbol, len - 1, 1);
        return proposalIds[0];
    }

    function updateSocialsWithValidation(
        Vm vm,
        address multisig,
        IHost host_,
        IHostCodec codec_,
        string memory symbol,
        string[] memory socials
    ) internal returns (bytes32 proposalId, bytes memory payload, bytes memory inputPayload) {
        vm.recordLogs();
        inputPayload = codec_.encode(socials, HostEncodingLib.API_VERSION);
        host_.updateDAO(symbol, uint16(IDAOData.DAOAction.UPDATE_SOCIALS_1), inputPayload, "");
        payload = EventUtilsLib.extractProposalPayload(vm.getRecordedLogs());
        proposalId = HostUtilsLib.getLastProposalId(host_, symbol);

        vm.prank(multisig);
        host_.validateProposal(proposalId, true, payload);
    }

    //endregion ----------------------------- Utils
}
