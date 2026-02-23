// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ContextLib} from "../engine/ContextLib.sol";
import {DeployUsesCaseLib} from "../uses-cases/DeployUsesCaseLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {HostDaoUsesCaseLib} from "../uses-cases/HostDaoUsesCaseLib.sol";
import {HostSetupLib} from "../engine/HostSetupLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {RestrictHostUtils} from "../access/RestrictHostUtils.sol";
import {SampleDataLib} from "../../utils/SampleDataLib.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {LifeCycleUsesCaseLib} from "../uses-cases/LifeCycleUsesCaseLib.sol";
// import {PrintUtilsLib} from "../../utils/PrintUtilsLib.sol";

/// @dev Uses cases for DAO "HOST"
contract HostDaoUsesCasesTest is Test {
    uint internal constant FORK_BLOCK = 24481863; // Feb-18-2026 06:15:47 AM +UTC
    uint internal constant CHAIN_ID = 1;

    EngineLib.BaseContext internal bc;

    EngineLib.ChainConfig internal core;

    uint internal forkId;

/// @dev Backend validator to validate proposals and register voting results
    address internal multisig;

    constructor() {
        forkId = vm.createFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK);
        vm.selectFork(forkId);

        bc = ContextLib.getBaseContext(CHAIN_ID, forkId);

        IProxyFactory proxyFactory = IProxyFactory(bc.configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address deployer = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(deployer);
        core = DeployUsesCaseLib.deployCore(bc, makeAddr("validator"));
        vm.stopPrank();

        multisig = bc.config.get(CHAIN_ID, "MULTISIG").toAddress();

        vm.startPrank(multisig);
        HostSetupLib.setupHostSettings(core);
        HostSetupLib.setupHostChainSettings(CHAIN_ID, core);
        HostSetupLib.setTokenImplementations(core);
        RestrictHostUtils.setupValidator(core.authority, address(core.host), core.hostValidator);
        vm.stopPrank();
    }

    function testCreateHostDao() public {
        EngineLib.Context memory context = ContextLib.getContext(core);
        deal(core.host.getChainSettings().exchangeAsset, address(this), 1000e18);

        IDAOData.DaoData memory dao = HostDaoUsesCaseLib.createHostDao(vm, context);

        // ---------------------------------- Check results
        assertEq(dao.symbol, HostDaoUsesCaseLib.HOST_DAO_SYMBOL, "DAO symbol is correct");

        {
            string[] memory socials = HostDaoUsesCaseLib.getHostSocials();
            assertEq(dao.socials, socials, "socials are correct");
        }

        {
            IDAOData.DaoParameters memory params = HostDaoUsesCaseLib.getHostDaoParameters();
            assertEq(keccak256(abi.encode(dao.params)), keccak256(abi.encode(params)), "DAO parameters are correct");
        }

        {
            IDAOData.DaoImages memory images = HostDaoUsesCaseLib.getHostDaoImages();
            assertEq(keccak256(abi.encode(dao.images)), keccak256(abi.encode(images)), "images are correct");
        }

        {
            IDAOData.Activity[] memory activity = HostDaoUsesCaseLib.getHostActivity();
            assertEq(keccak256(abi.encode(dao.activity)), keccak256(abi.encode(activity)), "activity are correct");
        }

        {
            IDAOData.Funding[] memory funding = HostDaoUsesCaseLib.getHostFunding();
            assertEq(keccak256(abi.encode(dao.funding)), keccak256(abi.encode(funding)), "funding are correct");
        }

        {
            (bytes32[] memory salts, uint16[] memory contractIndices) = HostDaoUsesCaseLib.getHostSalts(bc);
            assertEq(keccak256(abi.encode(dao.salts)), keccak256(abi.encode(salts)), "salts are correct");
            assertEq(
                keccak256(abi.encode(dao.saltContractIndices)),
                keccak256(abi.encode(contractIndices)),
                "contractIndices are correct"
            );
        }

        {
            IDAOData.DaoChainSettings memory chainSettings = HostDaoUsesCaseLib.getHostChainSettings(multisig);
            assertEq(
                keccak256(abi.encode(dao.chainSettings)),
                keccak256(abi.encode(chainSettings)),
                "chainSettings are correct"
            );
        }

        {
            (IDAOData.UnitDataInput[] memory units, ) = HostDaoUsesCaseLib.getHostUnits();
            assertEq(units.length, 1, "units length is correct 1");
            assertEq(dao.unitIds.length, 1, "units length is correct 2");
            assertEq(dao.units.length, 1, "units length is correct 3");

            assertEq(dao.unitIds[0], units[0].unitId, "unit id is correct 1");
            assertEq(dao.units[0].unitId, units[0].unitId, "unit id is correct 2");

            assertEq(dao.units[0].developerUid, units[0].developerUid, "developer uid is correct 2");

            assertEq(dao.units[0].chainIds.length, 1, "unit is registered on initial chain only");
            assertEq(dao.units[0].chainIds[0], block.chainid, "initial chain");
        }

        // todo check amount earned by DAO HOST
    }

    function testHostDaoSeeding_Success() public {
        address exchangeAsset = core.host.getChainSettings().exchangeAsset;

        // ---------------------------- create host dao
        EngineLib.Context memory context = ContextLib.getContext(core);
        deal(exchangeAsset, address(this), 1000e18);

        IDAOData.DaoData memory dao = HostDaoUsesCaseLib.createHostDao(vm, context);

        EngineLib.Funder[] memory funders = SampleDataLib.prepareFunders(
            exchangeAsset,
            (dao.funding[0].minRaise + dao.funding[0].maxRaise) / 2,
            5
        );

        LifeCycleUsesCaseLib.passSeedPhase(vm, context, dao, funders);

        // ---------------------------- check results
        IDAOData.DaoData memory daoAfter = core.dataReader.getDAO(dao.symbol);
        // PrintUtilsLib.printDaoData(daoAfter);

        assertEq(daoAfter.phase == IDAOData.LifecyclePhase.DEVELOPMENT_4, true, "development phase is ended");

        {   // ---------------------- raised amount = total amount funded by funders
            uint totalFunded;
            for (uint i; i < funders.length; ++i) {
                totalFunded += funders[i].amount;
            }
            assertEq(daoAfter.funding[0].raised, totalFunded, "raised amount is correct");

        }

        {   // ---------------------- seed token has expected amount on balance
            uint feeAmount = 0; // todo
            assertEq(
                IERC20(exchangeAsset).balanceOf(daoAfter.deployments.seedToken),
                daoAfter.funding[0].raised - feeAmount,
                "funds are on balance of seed token, fee is taken by DAO HOST"
            );
        }

        // todo check amount (fee) earned by DAO HOST
    }
}
