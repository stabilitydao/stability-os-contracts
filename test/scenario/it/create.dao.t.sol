// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {CreateDaoUsesCaseLib} from "../uses-cases/CreateDaoUsesCaseLib.sol";
import {DeployUsesCaseLib} from "../uses-cases/DeployUsesCaseLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {HostSetupUsesCaseLib} from "../uses-cases/HostSetupUsesCaseLib.sol";
import {RestrictHostUtils} from "../access/RestrictHostUtils.sol";
import {Test} from "forge-std/Test.sol";
// import {PrintUtilsLib} from "../../utils/PrintUtilsLib.sol";

contract CreateDaoUsesCasesTest is Test {
    uint internal constant FORK_BLOCK = 24481863; // Feb-18-2026 06:15:47 AM +UTC
    uint internal constant CHAIN_ID = 1;

    StdConfig internal config;
    StdConfig internal configDeployed;

    EngineLib.Core internal core;

    /// @dev Backend validator to validate proposals and register voting results
    address internal validator;
    address internal multisig;

    constructor() {
        vm.selectFork(vm.createFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK));

        configDeployed = new StdConfig("./config.d.toml", false);
        config = new StdConfig("./config.toml", false);

        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address deployer = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(deployer);
        core = DeployUsesCaseLib.deployCore(_getBaseContext());
        vm.stopPrank();

        multisig = config.get(CHAIN_ID, "MULTISIG").toAddress();

        vm.startPrank(multisig);
        HostSetupUsesCaseLib.setupHostSettings(core);
        HostSetupUsesCaseLib.setupHostChainSettings(CHAIN_ID, core);
        RestrictHostUtils.setupValidator(core.authority, address(core.host), validator);
        vm.stopPrank();
    }

    function testCreateHostDao() public {
        EngineLib.Context memory context = _getContext();
        deal(core.host.getChainSettings().exchangeAsset, address(this), 1000e18);

        IDAOData.DaoData memory dao = CreateDaoUsesCaseLib.createHostDao(vm, context);

        // ---------------------------------- Check results
        assertEq(dao.symbol, CreateDaoUsesCaseLib.HOST_DAO_SYMBOL, "DAO symbol is correct");

        {
            string[] memory socials = CreateDaoUsesCaseLib.getHostSocials();
            assertEq(dao.socials, socials, "socials are correct");
        }

        {
            IDAOData.DaoParameters memory params = CreateDaoUsesCaseLib.getHostDaoParameters();
            assertEq(keccak256(abi.encode(dao.params)), keccak256(abi.encode(params)), "DAO parameters are correct");
        }

        {
            IDAOData.DaoImages memory images = CreateDaoUsesCaseLib.getHostDaoImages();
            assertEq(keccak256(abi.encode(dao.images)), keccak256(abi.encode(images)), "images are correct");
        }

        {
            IDAOData.Activity[] memory activity = CreateDaoUsesCaseLib.getHostActivity();
            assertEq(keccak256(abi.encode(dao.activity)), keccak256(abi.encode(activity)), "activity are correct");
        }

        {
            IDAOData.Funding[] memory funding = CreateDaoUsesCaseLib.getHostFunding();
            assertEq(keccak256(abi.encode(dao.funding)), keccak256(abi.encode(funding)), "funding are correct");
        }

        {
            (bytes32[] memory salts, uint16[] memory contractIndices) =
                CreateDaoUsesCaseLib.getHostSalts(_getBaseContext());
            assertEq(keccak256(abi.encode(dao.salts)), keccak256(abi.encode(salts)), "salts are correct");
            assertEq(
                keccak256(abi.encode(dao.saltContractIndices)),
                keccak256(abi.encode(contractIndices)),
                "contractIndices are correct"
            );
        }

        {
            IDAOData.DaoChainSettings memory chainSettings = CreateDaoUsesCaseLib.getHostChainSettings(multisig);
            assertEq(
                keccak256(abi.encode(dao.chainSettings)),
                keccak256(abi.encode(chainSettings)),
                "chainSettings are correct"
            );
        }

        {
            (IDAOData.UnitDataInput[] memory units, IDAOData.UnitEmitData[] memory emitData) =
                CreateDaoUsesCaseLib.getHostUnits();
            assertEq(units.length, 1, "units length is correct 1");
            assertEq(dao.unitIds.length, 1, "units length is correct 2");
            assertEq(dao.units.length, 1, "units length is correct 3");

            assertEq(dao.unitIds[0], units[0].unitId, "unit id is correct 1");
            assertEq(dao.units[0].unitId, units[0].unitId, "unit id is correct 2");

            assertEq(dao.units[0].developerUid, units[0].developerUid, "developer uid is correct 2");

            assertEq(dao.units[0].chainIds.length, 1, "unit is registered on initial chain only");
            assertEq(dao.units[0].chainIds[0], block.chainid, "initial chain");
        }
    }

    //region --------------------------------------- Internal logic
    function _getBaseContext() internal view returns (EngineLib.BaseContext memory) {
        return EngineLib.BaseContext({configDeployed: configDeployed, config: config, chainId: CHAIN_ID});
    }

    function _getContext() internal view returns (EngineLib.Context memory) {
        address user = address(this);
        return
            EngineLib.Context({core: core, bc: _getBaseContext(), user: user, multisig: multisig, validator: validator});
    }
    //endregion --------------------------------------- Internal logic
}
