// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

//import {console} from "forge-std/console.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {Vm, Test} from "forge-std/Test.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {IHosted} from "../../../src/interfaces/IHosted.sol";
import {IHostCodec} from "../../../src/interfaces/IHostCodec.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {DeployUsesCaseLib} from "../uses-cases/DeployUsesCaseLib.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";

contract DeployUsesCasesTest is Test {
    uint internal constant FORK_BLOCK = 24481863; // Feb-18-2026 06:15:47 AM +UTC
    uint internal constant CHAIN_ID = 1;

    StdConfig internal config;
    StdConfig internal configDeployed;

    constructor() {
        vm.selectFork(vm.createFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK));

        configDeployed = new StdConfig("./config.d.toml", false);
        config = new StdConfig("./config.toml", false);
    }

    //region --------------------------------------- Deploy tests
    function testDeployCore() public {
        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(proxyFactoryOwner);
        EngineLib.Core memory core = DeployUsesCaseLib.deployCore(_getBaseContext());
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
        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(proxyFactoryOwner);
        IAuthority authority = DeployUsesCaseLib.deployAuthority(_getBaseContext());
        vm.stopPrank();

        // ---------------------------------- Check results
        (bool isMember, uint32 executionDelay) = authority.hasRole(0, proxyFactoryOwner);
        assertTrue(isMember, "Initial admin is correct");
        assertEq(executionDelay, 0, "no delay");

        bytes32 saltHost = config.get(CHAIN_ID, "SALT_HOST").toBytes32();
        assertEq(authority.HOST(), proxyFactory.predictAddress(saltHost), "Host is correct");
        assertEq(authority.PROXY_FACTORY(), address(proxyFactory), "Proxy factory is correct");
    }

    function testDeployHost() public {
        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(proxyFactoryOwner);

        /// @dev Assume here that Authority is not deployed yet
        IAuthority authority = DeployUsesCaseLib.deployAuthority(_getBaseContext());

        /// @dev Deploy host
        vm.recordLogs();
        IHost deployedHost = DeployUsesCaseLib.deployFirstHost(_getBaseContext(), address(authority));

        vm.stopPrank();

        /// ---------------------------------- Check results
        require(
            _extractDeployedProxy(vm.getRecordedLogs()) == authority.HOST(), "Host was deployed on predicted address"
        );

        assertEq(authority.HOST(), address(deployedHost), "Host deployed in proper address");
        assertEq(IHosted(address(deployedHost)).authority(), address(authority), "authority is correct");
    }

    function testDeployHostBridge() public {
        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();

        EngineLib.BaseContext memory bc = _getBaseContext();

        vm.startPrank(proxyFactoryOwner);

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
            _extractDeployedProxy(vm.getRecordedLogs())
                == proxyFactory.predictAddress(config.get(CHAIN_ID, "SALT_HOST_BRIDGE").toBytes32()),
            "Host bridge was deployed on predicted address"
        );

        assertNotEq(IHosted(address(hostBridge)).VERSION(), "", "host bridge has version");
    }

    function testDeployHostCodec() public {
        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();

        EngineLib.BaseContext memory bc = _getBaseContext();

        vm.startPrank(proxyFactoryOwner);

        /// @dev Assume here that Authority is not deployed yet
        IAuthority authority = DeployUsesCaseLib.deployAuthority(bc);

        vm.recordLogs();
        /// @dev Deploy host codec
        IHostCodec hostCodec = DeployUsesCaseLib.deployHostCodec(bc, address(authority));

        vm.stopPrank();

        /// ---------------------------------- Check results
        require(
            _extractDeployedProxy(vm.getRecordedLogs())
                == proxyFactory.predictAddress(config.get(CHAIN_ID, "SALT_HOST_CODEC").toBytes32()),
            "Host codec was deployed on predicted address"
        );

        assertNotEq(IHosted(address(hostCodec)).VERSION(), "", "host codec has version");
    }

    function testDeployDataReader() public {
        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();

        EngineLib.BaseContext memory bc = _getBaseContext();

        vm.startPrank(proxyFactoryOwner);

        /// @dev Assume here that Authority is not deployed yet
        IAuthority authority = DeployUsesCaseLib.deployAuthority(bc);

        vm.recordLogs();
        /// @dev Deploy host bridge
        IDataReader dataReader = DeployUsesCaseLib.deployDataReader(bc, address(authority));

        vm.stopPrank();

        /// ---------------------------------- Check results
        require(
            _extractDeployedProxy(vm.getRecordedLogs())
                == proxyFactory.predictAddress(config.get(CHAIN_ID, "SALT_DATA_READER").toBytes32()),
            "Data reader was deployed on predicted address"
        );

        assertNotEq(IHosted(address(dataReader)).VERSION(), "", "data reader has version");
    }

    //endregion --------------------------------------- Deploy tests

    //region --------------------------------------- Internal logic
    function _getBaseContext() internal view returns (EngineLib.BaseContext memory) {
        return EngineLib.BaseContext({configDeployed: configDeployed, config: config, chainId: CHAIN_ID});
    }

    function _extractDeployedProxy(Vm.Log[] memory entries) internal pure returns (address deployedProxy) {
        // Only support ProxyCreated(address) event: proxy is indexed (topics[1])
        bytes32 sigCreated = keccak256("ProxyCreated(address)");

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics.length != 0 && entries[i].topics[0] == sigCreated) {
                // ProxyCreated has indexed proxy => topics[1] contains the address
                if (entries[i].topics.length > 1) {
                    deployedProxy = address(uint160(uint(entries[i].topics[1])));
                } else {
                    // fallback: decode from data if not indexed for some reason
                    deployedProxy = abi.decode(entries[i].data, (address));
                }
                break;
            }
        }
        return deployedProxy;
    }
    //endregion --------------------------------------- Internal logic
}
