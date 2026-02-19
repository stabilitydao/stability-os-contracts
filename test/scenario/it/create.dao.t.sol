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
