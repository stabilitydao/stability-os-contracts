// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

//import {console} from "forge-std/console.sol";
import {ContextLib} from "../engine/ContextLib.sol";
import {DeployUsesCaseLib} from "../uses-cases/DeployUsesCaseLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {EventUtilsLib} from "../../utils/EventUtilsLib.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";
import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {IHostCodec} from "../../../src/interfaces/IHostCodec.sol";
import {IHosted} from "../../../src/interfaces/IHosted.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {Test} from "forge-std/Test.sol";

contract DeployUsesCaseTest is Test {
    uint internal constant FORK_BLOCK = 24481863; // Feb-18-2026 06:15:47 AM +UTC
    uint internal constant CHAIN_ID = 1;

    EngineLib.BaseContext internal bc;

    constructor() {
        uint forkId = vm.createFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK);
        vm.selectFork(forkId);

        bc = ContextLib.getBaseContext(CHAIN_ID, forkId);
    }

    //region --------------------------------------- Deploy tests
    function testDeployCore() public {
        IProxyFactory proxyFactory = IProxyFactory(bc.configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address deployer = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(deployer);
        EngineLib.ChainConfig memory core = DeployUsesCaseLib.deployCore(bc, makeAddr("validator"));
        vm.stopPrank();

        // ---------------------------------- Check results
        assertEq(core.authority.HOST(), address(core.host), "Host is correct");
        assertEq(IHosted(address(core.host)).authority(), address(core.authority), "authority is correct in host");
        assertEq(
            IHosted(address(core.hostBridge)).authority(),
            address(core.authority),
            "authority is correct in host bridge"
        );
        assertEq(
            IHosted(address(core.hostCodec)).authority(), address(core.authority), "authority is correct in host codec"
        );
        assertEq(
            IHosted(address(core.dataReader)).authority(),
            address(core.authority),
            "authority is correct in data reader"
        );
    }

    function testDeployAuthority() public {
        IProxyFactory proxyFactory = IProxyFactory(bc.configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address deployer = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(deployer);
        IAuthority authority = DeployUsesCaseLib.deployAuthority(bc);
        vm.stopPrank();

        // ---------------------------------- Check results
        (bool isMember, uint32 executionDelay) = authority.hasRole(0, deployer);
        assertTrue(isMember, "Initial admin is correct");
        assertEq(executionDelay, 0, "no delay");

        bytes32 saltHost = bc.config.get(CHAIN_ID, "SALT_HOST").toBytes32();
        assertEq(authority.HOST(), proxyFactory.predictAddress(saltHost), "Host is correct");
        assertEq(authority.PROXY_FACTORY(), address(proxyFactory), "Proxy factory is correct");
    }

    function testDeployHost() public {
        IProxyFactory proxyFactory = IProxyFactory(bc.configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address deployer = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(deployer);

        /// @dev Assume here that Authority is not deployed yet
        IAuthority authority = DeployUsesCaseLib.deployAuthority(bc);

        /// @dev Deploy host
        vm.recordLogs();
        IHost deployedHost = DeployUsesCaseLib.deployFirstHost(bc, address(authority));

        vm.stopPrank();

        /// ---------------------------------- Check results
        require(
            EventUtilsLib.extractDeployedProxy(vm.getRecordedLogs()) == authority.HOST(),
            "Host was deployed on predicted address"
        );

        assertEq(authority.HOST(), address(deployedHost), "Host deployed in proper address");
        assertEq(IHosted(address(deployedHost)).authority(), address(authority), "authority is correct");
    }

    function testDeployHostBridge() public {
        IProxyFactory proxyFactory = IProxyFactory(bc.configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address deployer = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(deployer);

        /// @dev Assume here that Authority is not deployed yet
        IAuthority authority = DeployUsesCaseLib.deployAuthority(bc);

        /// @dev Deploy host
        IHost host = DeployUsesCaseLib.deployFirstHost(bc, address(authority));

        vm.recordLogs();
        /// @dev Deploy host bridge
        IHostBridge hostBridge = DeployUsesCaseLib.deployHostBridge(bc, address(host));

        vm.stopPrank();

        /// ---------------------------------- Check results
        require(
            EventUtilsLib.extractDeployedProxy(vm.getRecordedLogs())
                == proxyFactory.predictAddress(bc.config.get(CHAIN_ID, "SALT_HOST_BRIDGE").toBytes32()),
            "Host bridge was deployed on predicted address"
        );

        assertNotEq(IHosted(address(hostBridge)).VERSION(), "", "host bridge has version");
    }

    function testDeployHostCodec() public {
        IProxyFactory proxyFactory = IProxyFactory(bc.configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address deployer = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(deployer);

        /// @dev Assume here that Authority is not deployed yet
        IAuthority authority = DeployUsesCaseLib.deployAuthority(bc);

        vm.recordLogs();
        /// @dev Deploy host codec
        IHostCodec hostCodec = DeployUsesCaseLib.deployHostCodec(bc, address(authority));

        vm.stopPrank();

        /// ---------------------------------- Check results
        require(
            EventUtilsLib.extractDeployedProxy(vm.getRecordedLogs())
                == proxyFactory.predictAddress(bc.config.get(CHAIN_ID, "SALT_HOST_CODEC").toBytes32()),
            "Host codec was deployed on predicted address"
        );

        assertNotEq(IHosted(address(hostCodec)).VERSION(), "", "host codec has version");
    }

    function testDeployDataReader() public {
        IProxyFactory proxyFactory = IProxyFactory(bc.configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address deployer = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(deployer);

        /// @dev Assume here that Authority is not deployed yet
        IAuthority authority = DeployUsesCaseLib.deployAuthority(bc);

        vm.recordLogs();
        /// @dev Deploy host bridge
        IDataReader dataReader = DeployUsesCaseLib.deployDataReader(bc, address(authority));

        vm.stopPrank();

        /// ---------------------------------- Check results
        require(
            EventUtilsLib.extractDeployedProxy(vm.getRecordedLogs())
                == proxyFactory.predictAddress(bc.config.get(CHAIN_ID, "SALT_DATA_READER").toBytes32()),
            "Data reader was deployed on predicted address"
        );

        assertNotEq(IHosted(address(dataReader)).VERSION(), "", "data reader has version");
    }

    //endregion --------------------------------------- Deploy tests
}
