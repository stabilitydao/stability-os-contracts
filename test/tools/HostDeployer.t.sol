// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HostDeployer} from "../../src/tools/HostDeployer.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IProxy} from "../../src/interfaces/IProxy.sol";
import {IHostAccessManager} from "../../src/interfaces/IHostAccessManager.sol";
import {HostAccessManager} from "../../src/HostAccessManager.sol";
import {Host} from "../../src/Host.sol";
import {AccessRolesLib} from "../../src/libs/AccessRolesLib.sol";
import {ProxyFactory} from "../../src/base/ProxyFactory.sol";

contract HostDeployerTest is Test {
    bytes32 internal constant HOST_PROXY_FACTORY_SALT = "0x111";
    bytes32 internal constant HOST_SALT = "0x333";
    address internal constant ADMIN = address(0x555);
    address internal constant UPGRADER = address(0x888);

    function testDeploy() public {
        ProxyFactory proxyFactory = new ProxyFactory();
        HostDeployer hostDeployer = new HostDeployer(address(proxyFactory));
        assertEq(hostDeployer.DEPLOYER(), address(this), "Deployer address");

        address hostProxyFactoryImpl = address(new HostProxyFactory(address(proxyFactory)));
        address hostImpl = address(new Host());
        bytes memory payload =
            abi.encode(IHost.HostInitPayload({usedSymbols: new string[](0), daoHostSymbol: "A", daoHostUid: 999}));

        vm.prank(address(123));
        vm.expectRevert(HostDeployer.NotDeployer.selector);
        hostDeployer.deploy(HOST_PROXY_FACTORY_SALT, HOST_SALT, ADMIN, payload, hostProxyFactoryImpl, hostImpl);

        (address accessManager, address hostProxyFactory, address host) =
            hostDeployer.deploy(HOST_PROXY_FACTORY_SALT, HOST_SALT, ADMIN, payload, hostProxyFactoryImpl, hostImpl);

        address expectedHost = proxyFactory.getCreate2Address(HOST_SALT, proxyFactory.getProxyInitCodeHash(), address(proxyFactory));
        address expectedHostProxyFactory = proxyFactory.getCreate2Address(HOST_PROXY_FACTORY_SALT, proxyFactory.getProxyInitCodeHash(), address(proxyFactory));

        assertEq(expectedHostProxyFactory, hostProxyFactory, "HostProxyFactory address");

        assertEq(expectedHost, host, "hostSalt address");

        assertEq(IHostAccessManager(accessManager).HOST(), expectedHost, "expected host");

        assertEq(IHosted(hostProxyFactory).authority(), accessManager, "authority of host proxy factory");
        assertEq(IHosted(host).authority(), accessManager, "authority of host");
    }

    function testUpgradeProxy() public {
        ProxyFactory proxyFactory = new ProxyFactory();
        HostAccessManager accessManager;
        HostProxyFactory hostProxyFactory;
        Host host;

        // ------------------------------ Deploy initial contracts: HostAccessManager, HostProxyFactory, Host
        {
            HostDeployer deployer = new HostDeployer(address(proxyFactory));
            assertEq(deployer.DEPLOYER(), address(this), "Deployer address");

            address hostProxyFactoryImpl = address(new HostProxyFactory(address(proxyFactory)));
            address hostImpl = address(new Host());
            bytes memory payload =
                abi.encode(IHost.HostInitPayload({usedSymbols: new string[](0), daoHostSymbol: "A", daoHostUid: 999}));

            (address _accessManager, address _hostProxyFactory, address _host) =
                deployer.deploy(HOST_PROXY_FACTORY_SALT, HOST_SALT, ADMIN, payload, hostProxyFactoryImpl, hostImpl);

            accessManager = HostAccessManager(_accessManager);
            hostProxyFactory = HostProxyFactory(_hostProxyFactory);
            host = Host(_host);

            assertEq(IProxy(address(hostProxyFactory)).implementation(), hostProxyFactoryImpl, "first impl");
        }

        // ------------------------------ Initial ADMIN sets up authority - allow UPGRADER to upgrade HostProxyFactory
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(keccak256("upgradeToAndCall(address,bytes)"));

            vm.expectRevert(); // AccessManagedUnauthorized
            accessManager.setTargetFunctionRole(address(hostProxyFactory), selectors, AccessRolesLib.CONTRACTS_UPGRADER);

            vm.prank(ADMIN);
            accessManager.setTargetFunctionRole(address(hostProxyFactory), selectors, AccessRolesLib.CONTRACTS_UPGRADER);

            vm.prank(ADMIN);
            accessManager.grantRole(AccessRolesLib.CONTRACTS_UPGRADER, UPGRADER, 0);
        }

        // ------------------------------ UPGRADER upgrades implementation of HostProxyFactory
        {
            address newHostProxyFactoryImpl = address(new HostProxyFactory(address(proxyFactory)));

            vm.expectRevert(); // AccessManagedUnauthorized
            hostProxyFactory.upgradeToAndCall(newHostProxyFactoryImpl, "");

            vm.prank(UPGRADER);
            hostProxyFactory.upgradeToAndCall(newHostProxyFactoryImpl, "");

            assertEq(IProxy(address(hostProxyFactory)).implementation(), newHostProxyFactoryImpl, "new impl");
        }
    }
}
