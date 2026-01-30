// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {HostUtilsLib} from "../utils/HostUtilsLib.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {IUUPSUpgradable} from "../../src/interfaces/IUUPSUpgradable.sol";
import {Vm, Test} from "forge-std/Test.sol";
import {MinHostedNoReceive} from "../mocks/MinHostedNoReceive.sol";
import {MinHostedNoReceiveV2} from "../mocks/MinHostedNoReceiveV2.sol";
import {AccessRolesLib} from "../../src/libs/AccessRolesLib.sol";

contract HostUpgradeProxyLibTest is Test {
    address internal immutable MULTISIG;

    constructor() {
        MULTISIG = makeAddr("multisig");
    }

    function testUpgradeHost() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        address authority = IAccessManaged(address(host)).authority();
        _setupAccessManager(authority, address(host));

        // ------------------------- Deploy two proxies
        vm.startPrank(MULTISIG);
        address[] memory proxies = new address[](2);
        proxies[0] = host.deployProxy("0x1", address(new MinHostedNoReceive()), "");
        proxies[1] = host.deployProxy("0x2", address(new MinHostedNoReceiveV2()), "");
        vm.stopPrank();

        // ------------------------- Allow host to upgrade proxies
        _setupContractUpgrader(authority, proxies[0], address(host));
        _setupContractUpgrader(authority, proxies[1], address(host));

        // ------------------------- Create new implementations
        address[] memory implementations = new address[](2);
        implementations[0] = address(new MinHostedNoReceiveV2()); // upgrade
        implementations[1] = address(new MinHostedNoReceive()); // downgrade

        // ------------------------- Announce upgrade
        vm.prank(MULTISIG);
        host.announceUpgrade("1.1.0", proxies, implementations);

        {
            (string memory newVersion, address[] memory newProxies, address[] memory newImplementations) =
                host.pendingPlatformUpgrade();
            assertEq(keccak256(bytes(newVersion)), keccak256(bytes("1.1.0")), "new version announced");
            assertEq(keccak256(abi.encode(newProxies)), keccak256(abi.encode(proxies)), "proxies announced");
            assertEq(
                keccak256(abi.encode(newImplementations)),
                keccak256(abi.encode(implementations)),
                "implementations announced"
            );
        }

        // ------------------------- Wait timelock
        vm.warp(block.timestamp + 31 minutes);

        // ------------------------- Check functions before upgrade
        vm.expectRevert();
        MinHostedNoReceiveV2(proxies[0]).newFunction();
        MinHostedNoReceiveV2(proxies[1]).newFunction();

        assertEq(MinHostedNoReceive(proxies[0]).testFunction(), 1, "before 1");
        assertEq(MinHostedNoReceiveV2(proxies[1]).testFunction(), 1, "before 2");

        // ------------------------- Upgrade and check functions after upgrade
        vm.prank(MULTISIG);
        host.upgrade();

        {
            (string memory newVersion, address[] memory newProxies, address[] memory newImplementations) =
                host.pendingPlatformUpgrade();
            assertEq(keccak256(bytes(newVersion)), keccak256(bytes("")), "no new version announced");
            assertEq(keccak256(abi.encode(newProxies)), keccak256(abi.encode(proxies)), "proxies announced");
            assertEq(
                keccak256(abi.encode(newImplementations)),
                keccak256(abi.encode(implementations)),
                "implementations announced"
            );
        }

        MinHostedNoReceiveV2(proxies[0]).newFunction();
        vm.expectRevert();
        MinHostedNoReceiveV2(proxies[1]).newFunction();

        assertEq(MinHostedNoReceiveV2(proxies[0]).testFunction(), 1, "after 1");
        assertEq(MinHostedNoReceive(proxies[1]).testFunction(), 1, "after 2");

        assertEq(keccak256(bytes(IHosted(proxies[0]).VERSION())), keccak256(bytes("2.0.0")), "version 2 after upgrade ");
        assertEq(keccak256(bytes(IHosted(proxies[1]).VERSION())), keccak256(bytes("1.0.0")), "version 1 after upgrade ");

        assertEq(host.hostVersion(), "1.1.0", "host version is updated");
    }

    function testUpgradeHostBadPaths() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        address authority = IAccessManaged(address(host)).authority();
        _setupAccessManager(authority, address(host));

        // ------------------------- Deploy two proxies
        vm.startPrank(MULTISIG);
        address[] memory proxies = new address[](2);
        proxies[0] = host.deployProxy("0x1", address(new MinHostedNoReceive()), "");
        proxies[1] = host.deployProxy("0x2", address(new MinHostedNoReceiveV2()), "");
        vm.stopPrank();

        // ------------------------- Allow host to upgrade proxies
        _setupContractUpgrader(authority, proxies[0], address(host));
        _setupContractUpgrader(authority, proxies[1], address(host));

        // ------------------------- Create new implementations
        address[] memory implementations = new address[](2);
        implementations[0] = address(new MinHostedNoReceiveV2()); // upgrade
        implementations[1] = address(new MinHostedNoReceive()); // downgrade

        // ------------------------- Bad paths
        {
            address[] memory implementations2 = new address[](1);
            implementations2[0] = address(new MinHostedNoReceiveV2()); // upgrade

            vm.expectRevert(IHost.IncorrectArrayLengths.selector);
            vm.prank(MULTISIG);
            host.announceUpgrade("1.1.0", proxies, implementations2);

            implementations2 = new address[](implementations.length);
            for (uint i = 0; i < implementations.length - 1; i++) {
                implementations2[i] = i == 0 ? address(0) : implementations[i];
            }

            vm.expectRevert(IHosted.IncorrectZeroArgument.selector);
            vm.prank(MULTISIG);
            host.announceUpgrade("1.1.0", proxies, implementations2);

            vm.expectRevert(IHosted.IncorrectZeroArgument.selector);
            vm.prank(MULTISIG);
            host.announceUpgrade("1.1.0", implementations2, proxies);

            implementations2 = new address[](2);
            implementations[0] = address(new MinHostedNoReceive()); // upgrade
            implementations[1] = address(new MinHostedNoReceiveV2()); // downgrade

            vm.expectRevert(IHost.SameVersion.selector);
            vm.prank(MULTISIG);
            host.announceUpgrade("1.1.0", implementations2, proxies);

            vm.expectRevert(IHost.SameVersion.selector);
            vm.prank(MULTISIG);
            host.announceUpgrade("", implementations, proxies);

            vm.expectRevert(); // restricted
            vm.prank(address(0x1111));
            host.announceUpgrade("1.1.0", proxies, implementations);
        }

        // ------------------------- Announce upgrade
        vm.prank(MULTISIG);
        host.announceUpgrade("1.1.0", proxies, implementations);

        // ------------------------- Bad paths
        {
            // We cannot announce next upgrade before executing or cancelling the previous one
            vm.expectRevert(IHost.AlreadyAnnounced.selector);
            vm.prank(MULTISIG);
            host.announceUpgrade("1.2.0", proxies, implementations);

            // We cannot upgrade before timelock
            vm.prank(MULTISIG);
            host.upgrade();
        }

        // ------------------------- Wait timelock
        vm.warp(block.timestamp + 31 minutes);

        // ------------------------- Upgrade and check functions after upgrade
        vm.expectRevert(); // restricted
        vm.prank(address(0x1));
        host.upgrade();

        vm.prank(MULTISIG);
        host.upgrade();

        // ------------------------- Bad paths
        {
            // nothing to cancel
            vm.prank(MULTISIG);
            host.cancelUpgrade();
        }
    }

    function testCancelUpgradeHost() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        address authority = IAccessManaged(address(host)).authority();
        _setupAccessManager(authority, address(host));

        // ------------------------- Deploy two proxies
        vm.startPrank(MULTISIG);
        address[] memory proxies = new address[](2);
        proxies[0] = host.deployProxy("0x1", address(new MinHostedNoReceive()), "");
        proxies[1] = host.deployProxy("0x2", address(new MinHostedNoReceiveV2()), "");
        vm.stopPrank();

        // ------------------------- Allow host to upgrade proxies
        _setupContractUpgrader(authority, proxies[0], address(host));
        _setupContractUpgrader(authority, proxies[1], address(host));

        // ------------------------- Create new implementations
        address[] memory implementations = new address[](2);
        implementations[0] = address(new MinHostedNoReceiveV2()); // upgrade
        implementations[1] = address(new MinHostedNoReceive()); // downgrade

        // ------------------------- Announce upgrade
        vm.prank(MULTISIG);
        host.announceUpgrade("1.1.0", proxies, implementations);

        assertEq(keccak256(bytes(IHosted(proxies[0]).VERSION())), keccak256(bytes("1.0.0")), "version not changed");
        assertEq(keccak256(bytes(IHosted(proxies[1]).VERSION())), keccak256(bytes("2.0.0")), "version not changed");

        // ------------------------- Cancel upgrade at any time
        vm.prank(MULTISIG);
        host.cancelUpgrade();

        assertEq(keccak256(bytes(IHosted(proxies[0]).VERSION())), keccak256(bytes("1.0.0")), "version not changed");
        assertEq(keccak256(bytes(IHosted(proxies[1]).VERSION())), keccak256(bytes("2.0.0")), "version not changed");

        assertEq(host.hostVersion(), "1.0.0", "host version is NOT updated");
    }

    //region ------------------------------------- Internal utils
    function _setupAccessManager(address authority, address host) internal {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = bytes4(IHost.upgrade.selector);
        selectors[1] = bytes4(IHost.announceUpgrade.selector);
        selectors[2] = bytes4(IHost.cancelUpgrade.selector);
        selectors[3] = bytes4(IHost.deployProxy.selector);

        vm.prank(MULTISIG);
        IAccessManager(address(authority)).setTargetFunctionRole(host, selectors, AccessRolesLib.HOST_UPGRADER);

        vm.prank(MULTISIG);
        IAccessManager(authority).grantRole(AccessRolesLib.HOST_UPGRADER, MULTISIG, 0);

        vm.prank(MULTISIG);
        IAccessManager(authority).grantRole(AccessRolesLib.HOST_UPGRADER, address(this), 0);
    }

    function _setupContractUpgrader(address authority, address proxy, address upgrader) internal {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(IUUPSUpgradable.upgradeToAndCall.selector);

        vm.prank(MULTISIG);
        IAccessManager(authority).setTargetFunctionRole(proxy, selectors, AccessRolesLib.CONTRACTS_UPGRADER);

        vm.prank(MULTISIG);
        IAccessManager(authority).grantRole(AccessRolesLib.CONTRACTS_UPGRADER, upgrader, 0);
    }
    //endregion ------------------------------------- Internal utils
}
