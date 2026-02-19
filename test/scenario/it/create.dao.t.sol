// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

//import {console} from "forge-std/console.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {CreateDaoUsesCaseLib} from "../uses-cases/CreateDaoUsesCaseLib.sol";
import {DeployUsesCaseLib} from "../uses-cases/DeployUsesCaseLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";
import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {IHostCodec} from "../../../src/interfaces/IHostCodec.sol";
import {IHosted} from "../../../src/interfaces/IHosted.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {HostSetupUsesCaseLib} from "../uses-cases/HostSetupUsesCaseLib.sol";
import {Vm, Test} from "forge-std/Test.sol";

contract CreateDaoUsesCasesTest is Test {
    uint internal constant FORK_BLOCK = 24481863; // Feb-18-2026 06:15:47 AM +UTC
    uint internal constant CHAIN_ID = 1;

    StdConfig internal config;
    StdConfig internal configDeployed;

    EngineLib.Core internal core;

    constructor() {
        vm.selectFork(vm.createFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK));

        configDeployed = new StdConfig("./config.d.toml", false);
        config = new StdConfig("./config.toml", false);

        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(proxyFactoryOwner);
        core = DeployUsesCaseLib.deployCore(_getBaseContext());
        vm.stopPrank();

        vm.startPrank(core.multisig);
        HostSetupUsesCaseLib.setupHostSettings(core);
        HostSetupUsesCaseLib.setupHostChainSettings(CHAIN_ID, core);
        vm.stopPrank();
    }

    function testCreateHostDao() public {
        deal(core.host.getChainSettings().exchangeAsset, address(this), 1000e18);

        IDAOData.DaoData memory dao = CreateDaoUsesCaseLib.createHostDao(core);

        // ---------------------------------- Check results
        assertEq(dao.symbol, CreateDaoUsesCaseLib.HOST_DAO_SYMBOL, "DAO symbol is correct");
    }

    //region --------------------------------------- Internal logic
    function _getBaseContext() internal view returns (EngineLib.BaseContext memory) {
        return EngineLib.BaseContext({configDeployed: configDeployed, config: config, chainId: CHAIN_ID});
    }
    //endregion --------------------------------------- Internal logic

}