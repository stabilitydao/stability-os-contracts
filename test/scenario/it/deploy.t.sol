// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {Test} from "forge-std/Test.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {IHosted} from "../../../src/interfaces/IHosted.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {DeployUsesCaseLib} from "../uses-cases/DeployUsesCaseLib.sol";

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

    function testDeployAuthority() public {
        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();

        IAuthority authority = DeployUsesCaseLib.deployAuthority(vm, _getBaseContext());

        // ---------------------------------- Check results
        (bool isMember, uint32 executionDelay) = authority.hasRole(0, proxyFactoryOwner);
        assertTrue(isMember, "Initial admin is correct");
        assertEq(executionDelay, 0, "no delay");

        bytes32 saltHost = config.get(CHAIN_ID, "SALT_HOST").toBytes32();
        assertEq(authority.HOST(), proxyFactory.predictAddress(saltHost), "Host is correct");
        assertEq(authority.PROXY_FACTORY(), address(proxyFactory), "Proxy factory is correct");
    }

    function testDeployHost() public {
        /// @dev Assume here that Authority is not deployed yet
        IAuthority authority = DeployUsesCaseLib.deployAuthority(vm, _getBaseContext());

        /// @dev Deploy host
        IHost deployedHost = DeployUsesCaseLib.deployFirstHost(vm, _getBaseContext(), address(authority));

        /// ---------------------------------- Check results
        assertEq(authority.HOST(), address(deployedHost), "Host deployed in proper address");
        assertEq(IHosted(address(deployedHost)).authority(), address(authority), "authority is correct");
    }

    function testDeployHostBridge() public {
        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(CHAIN_ID, "PROXY_FACTORY").toAddress());
        EngineLib.BaseContext memory bc = _getBaseContext();
        /// @dev Assume here that Authority is not deployed yet
        IAuthority authority = DeployUsesCaseLib.deployAuthority(vm, bc);

        /// @dev Deploy host
        IHost host = DeployUsesCaseLib.deployFirstHost(vm, bc, address(authority));

        /// @dev Deploy host bridge
        IHostBridge hostBridge = DeployUsesCaseLib.deployHostBridge(vm, bc, address(host));

        /// ---------------------------------- Check results
        // todo
        assertEq(
            address(hostBridge),
            proxyFactory.predictAddress(config.get(CHAIN_ID, "SALT_HOST_BRIDGE").toBytes32()),
            "expected host bridge address"
        );
    }

    function testDeployHostCodec() public {}

    function testDeployDataReader() public {}

    function testDeployAll() public {}

    function _getBaseContext() internal view returns (EngineLib.BaseContext memory) {
        return EngineLib.BaseContext({configDeployed: configDeployed, config: config, chainId: CHAIN_ID});
    }
}
