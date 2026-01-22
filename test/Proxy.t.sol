// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IHosted} from "../src/interfaces/IHosted.sol";
import {IHost} from "../src/interfaces/IHost.sol";
import {IProxy} from "../src/interfaces/IProxy.sol";
import {IProxyFactory} from "../src/interfaces/IProxyFactory.sol";
import {Authority} from "../src/Authority.sol";
import {Host} from "../src/Host.sol";
import {HostBridge} from "../src/HostBridge.sol";
import {AccessRolesLib} from "../src/libs/AccessRolesLib.sol";
import {ProxyFactory} from "../src/ProxyFactory.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract ProxyTest is Test {
    address internal constant MULTISIG = address(0xFFFFFFFF);
    address internal constant UPGRADER = address(0xAAAAAAA1);

    ProxyFactory internal proxyFactory;
    Authority internal authority;
    IHost.HostInitPayload internal emptyHostPayload;
    IHost.HostInitPayload internal notEmptyHostPayload;
    address internal logic;

    constructor() {
        emptyHostPayload = IHost.HostInitPayload({usedSymbols: new string[](0), daoHostSymbol: "", daoHostUid: 0});
        {
            string[] memory usedSymbols = new string[](1);
            usedSymbols[0] = "B";

            notEmptyHostPayload = IHost.HostInitPayload({usedSymbols: usedSymbols, daoHostSymbol: "A", daoHostUid: 1});
        }

        logic = address(new Host());

        // ------------------- deploy proxy factory
        vm.prank(MULTISIG);
        proxyFactory = new ProxyFactory();

        // ------------------- deploy authority
        address hostPredicted = proxyFactory.getCreate2Address("0x62436");
        authority = new Authority(MULTISIG, hostPredicted, address(proxyFactory));

        vm.prank(MULTISIG);
        proxyFactory.setWhitelisted(address(authority), true);

        vm.prank(MULTISIG);
        proxyFactory.setWhitelisted(hostPredicted, true);
    }

    function testInitializeProxyAndLogic() public {
        vm.prank(MULTISIG);
        authority.execute(
            address(proxyFactory),
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                (
                    "0x62436",
                    logic,
                    abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(notEmptyHostPayload)))
                )
            )
        );

        address host = authority.HOST();

        assertEq(IProxy(host).implementation(), logic, "logic is set");
        assertEq(IAccessManaged(host).authority(), address(authority), "authority is set");
        assertNotEq(IHost(host).getHostDaoUid(), 0, "host dao uid is set");

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        IHosted(host).initialize(address(authority), abi.encode(emptyHostPayload));
    }

    function testInitializeProxyWithoutLogicInitialization() public {
        vm.prank(MULTISIG);
        authority.execute(address(proxyFactory), abi.encodeCall(IProxyFactory.create2NewProxy, ("0x62436", logic, "")));

        address host = authority.HOST();

        assertEq(IProxy(host).implementation(), logic, "logic is set");
        assertEq(IAccessManaged(host).authority(), address(0), "logic is not initialized");

        IHosted(host).initialize(address(authority), abi.encode(notEmptyHostPayload));

        assertEq(IAccessManaged(host).authority(), address(authority), "authority is set");

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        IHosted(host).initialize(address(authority), abi.encode(notEmptyHostPayload));
    }

    function testUpgradeProxy() public {
        // ------------------- create host
        vm.prank(MULTISIG);
        authority.execute(
            address(proxyFactory),
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                (
                    "0x62436",
                    logic,
                    abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(notEmptyHostPayload)))
                )
            )
        );

        Host host = Host(authority.HOST());

        // ------------------------------ Initial ADMIN sets up authority - allow UPGRADER to upgrade Host
        {
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(keccak256("upgradeToAndCall(address,bytes)"));

            vm.expectRevert(); // AccessManagedUnauthorized
            authority.setTargetFunctionRole(address(host), selectors, AccessRolesLib.CONTRACTS_UPGRADER);

            vm.prank(MULTISIG);
            authority.setTargetFunctionRole(address(host), selectors, AccessRolesLib.CONTRACTS_UPGRADER);

            vm.prank(MULTISIG);
            authority.grantRole(AccessRolesLib.CONTRACTS_UPGRADER, UPGRADER, 0);
        }

        // ------------------------------ UPGRADER upgrades implementation: Host => HostBridge
        {
            assertEq(IProxy(address(host)).implementation(), logic, "old impl");

            // pretend here that "HostBridge" is a "new implementation" of Host contract
            address hostNewImpl = address(new HostBridge(makeAddr("endpoint")));

            vm.expectRevert(); // AccessManagedUnauthorized
            host.upgradeToAndCall(hostNewImpl, "");

            vm.prank(UPGRADER);
            host.upgradeToAndCall(hostNewImpl, "");

            assertEq(IProxy(address(host)).implementation(), hostNewImpl, "new impl");
        }

        // ------------------------------ UPGRADER upgrades implementation: HostBridge => Host
        {
            vm.expectRevert();
            vm.prank(UPGRADER);
            host.upgradeToAndCall(address(0), "");

            vm.prank(UPGRADER);
            host.upgradeToAndCall(logic, "");

            assertEq(IProxy(address(host)).implementation(), logic, "restored impl");
        }
    }

    function testTryToInitializeProxyWithEmptyImplementation() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1967Utils.ERC1967InvalidImplementation.selector, address(0)));
        vm.prank(MULTISIG);
        authority.execute(
            address(proxyFactory),
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                (
                    "0x62436",
                    address(0), // (!)
                    abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(emptyHostPayload)))
                )
            )
        );
    }

    function testTryToInitializeProxySecondTime() public {
        vm.prank(MULTISIG);
        authority.execute(
            address(proxyFactory),
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                (
                    "0x62436",
                    logic,
                    abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(emptyHostPayload)))
                )
            )
        );

        address host = authority.HOST();

        assertNotEq(IProxy(host).implementation(), address(0), "implementation is set");

        vm.expectRevert(IProxy.ProxyAlreadyInitialized.selector);
        IProxy(host).initProxy(logic, "");
    }
}

