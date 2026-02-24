// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {UpdateDaoUsesCasesLib} from "../uses-cases/UpdateDaoUsesCasesLib.sol";
import {ContextLib} from "../engine/ContextLib.sol";
import {DeployUsesCaseLib} from "../uses-cases/DeployUsesCaseLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {HostDaoUsesCaseLib} from "../uses-cases/HostDaoUsesCaseLib.sol";
import {HostSetupLib} from "../engine/HostSetupLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {LifeCycleUsesCaseLib} from "../uses-cases/LifeCycleUsesCaseLib.sol";
import {RestrictHostUtils} from "../access/RestrictHostUtils.sol";
import {SampleDataLib} from "../../utils/SampleDataLib.sol";
import {Test} from "forge-std/Test.sol";

//import {console} from "forge-std/console.sol";
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

    //region ---------------------------- Tests
    function testCreateHostDao() public {
        EngineLib.Context memory context = ContextLib.getContext(core, address(this));
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
            (IDAOData.UnitDataInput[] memory units,) = HostDaoUsesCaseLib.getHostUnits();
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
        EngineLib.Context memory context = ContextLib.getContext(core, address(this));
        deal(exchangeAsset, address(this), 1000e18);

        IDAOData.DaoData memory dao = HostDaoUsesCaseLib.createHostDao(vm, context);

        EngineLib.Funder[] memory funders =
            SampleDataLib.prepareFunders(exchangeAsset, (dao.funding[0].minRaise + dao.funding[0].maxRaise) / 2, 5);

        LifeCycleUsesCaseLib.moveToDevelopmentPhaseFromDraft(vm, context, dao, funders);

        // ---------------------------- check results
        IDAOData.DaoData memory daoAfter = core.dataReader.getDAO(dao.symbol);
        // PrintUtilsLib.printDaoData(daoAfter);

        assertEq(daoAfter.phase == IDAOData.LifecyclePhase.DEVELOPMENT_4, true, "development phase is ended");

        { // ---------------------- raised amount = total amount funded by funders
            uint totalFunded;
            for (uint i; i < funders.length; ++i) {
                totalFunded += funders[i].amount;
            }
            assertEq(daoAfter.funding[0].raised, totalFunded, "raised amount is correct");
        }

        { // ---------------------- seed token has expected amount on balance
            uint feeAmount = 0; // todo
            assertEq(
                IERC20(exchangeAsset).balanceOf(daoAfter.deployments.seedToken),
                daoAfter.funding[0].raised - feeAmount,
                "funds are on balance of seed token, fee is taken by DAO HOST"
            );
        }

        // todo check amount (fee) earned by DAO HOST
    }

    //endregion ---------------------------- Tests

    //region ---------------------------- Test update on each phase
    /// @dev List of all supported phases
    function fixturePhases() public pure returns (IDAOData.LifecyclePhase[] memory) {
        IDAOData.LifecyclePhase[] memory phases = new IDAOData.LifecyclePhase[](3);
        phases[0] = IDAOData.LifecyclePhase.INCEPTION_1;
        phases[1] = IDAOData.LifecyclePhase.SEED_2;
        phases[2] = IDAOData.LifecyclePhase.DEVELOPMENT_4;

        return phases;
    }

    function tableHostUpdateImages_Success(IDAOData.LifecyclePhase phases) public {
        (EngineLib.Context memory context, IDAOData.DaoData memory dao) = _prepareDaoInGivenPhase(phases);

        IDAOData.DaoImages memory newImages = SampleDataLib.getDaoImages();
        IDAOData.DaoImages memory updatedImages = UpdateDaoUsesCasesLib.updateImages(
            vm,
            address(this),
            context.core,
            _getTargetStub(),
            dao.symbol,
            newImages
        ).images;

        assertEq(keccak256(abi.encode(updatedImages)), keccak256(abi.encode(newImages)), "images are updated correctly");
    }

    function tableHostUpdateSocials_Success(IDAOData.LifecyclePhase phases) public {
        (EngineLib.Context memory context, IDAOData.DaoData memory dao) = _prepareDaoInGivenPhase(phases);

        string[] memory newSocials = SampleDataLib.getSocialsThree();
        string[] memory socials = UpdateDaoUsesCasesLib.updateSocials(
            vm,
            address(this),
            context.core,
            _getTargetStub(),
            dao.symbol,
            newSocials
        ).socials;

        assertEq(keccak256(abi.encode(socials)), keccak256(abi.encode(newSocials)), "socials are updated correctly");
    }

    //endregion ---------------------------- Test update on each phase

    //region ---------------------------- Internal utils
    function _prepareDaoInGivenPhase(IDAOData.LifecyclePhase phases) internal returns (
        EngineLib.Context memory,
        IDAOData.DaoData memory
    ){
        address exchangeAsset = core.host.getChainSettings().exchangeAsset;

        // ---------------------------- create host dao
        EngineLib.Context memory context = ContextLib.getContext(core, address(this));
        deal(exchangeAsset, address(this), 1000e18);

        IDAOData.DaoData memory dao = HostDaoUsesCaseLib.createHostDao(vm, context);

        EngineLib.Funder[] memory funders =
                            SampleDataLib.prepareFunders(exchangeAsset, (dao.funding[0].minRaise + dao.funding[0].maxRaise) / 2, 5);

        // ---------------------------- Move to selected phase
        if (phases == IDAOData.LifecyclePhase.INCEPTION_1) {
            LifeCycleUsesCaseLib.moveToInceptionPhaseFromDraft(context, dao);
        } else if (phases == IDAOData.LifecyclePhase.SEED_2) {
            LifeCycleUsesCaseLib.moveToSeedPhaseFromDraft(vm, context, dao, funders);
        } else if (phases == IDAOData.LifecyclePhase.DEVELOPMENT_4) {
            LifeCycleUsesCaseLib.moveToDevelopmentPhaseFromDraft(vm, context, dao, funders);
        }

        return (context, core.dataReader.getDAO(dao.symbol));
    }

    /// @dev If we don't expect any cross-chain messages we can use stub of ChainConfig with zero chainId
    function _getTargetStub() internal pure returns (EngineLib.ChainConfig memory dest) {
        return dest;
    }

    //endregion ---------------------------- Internal utils
}
