// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Test.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {MockHost} from "../../mocks/MockHost.sol";
import {ProxyFactory} from "../../../src/ProxyFactory.sol";
import {Authority} from "../../../src/Authority.sol";
import {AccessRolesLib} from "../../../src/libs/AccessRolesLib.sol";

library AuthorityAccessUtils {
    /// @dev Get Authority from Host
    function getAuthority(IHost host) internal view returns (IAuthority) {
        return IAuthority(IAccessManaged(address(host)).authority());
    }

    /// @dev Create Authority for tests where host doesn't matter, whitelist address(this) and authority in ProxyFactory
    function createAuthorityMockedHostWhitelistThis(Vm vm, address multisig) internal returns (IAuthority) {
        vm.prank(multisig);
        ProxyFactory proxyFactory = new ProxyFactory();

        MockHost _host = new MockHost();

        Authority _authority = new Authority(multisig, address(_host), address(proxyFactory));

        vm.prank(multisig);
        proxyFactory.setWhitelisted(address(_authority), true);

        vm.prank(multisig);
        proxyFactory.setWhitelisted(address(this), true);

        return _authority;
    }

    /// @dev Provide assess to restricted target function for user by setting role permissions in Authority
    function setRestrictedAccess(
        Vm vm,
        address multisig,
        IAuthority authority,
        address user,
        uint64 role,
        address target,
        bytes4 selector
    ) internal {
        bytes4[] memory _selectors = new bytes4[](1);
        _selectors[0] = selector;

        vm.prank(multisig);
        authority.setTargetFunctionRole(target, _selectors, role);

        vm.prank(multisig);
        authority.grantRole(role, user, 0);
    }

    /// @dev Provide assess to restricted 2 target functions for user by setting role permissions in Authority
    function setRestrictedAccess(
        Vm vm,
        address multisig,
        IAuthority authority,
        address user,
        uint64 role,
        address target,
        bytes4 selector1,
        bytes4 selector2
    ) internal {
        bytes4[] memory _selectors = new bytes4[](2);
        _selectors[0] = selector1;
        _selectors[1] = selector2;

        vm.prank(multisig);
        authority.setTargetFunctionRole(target, _selectors, role);

        vm.prank(multisig);
        authority.grantRole(role, user, 0);
    }

    /// @dev Provide assess to restricted 2 target functions for user by setting role permissions in Authority
    function setRestrictedAccess(
        Vm vm,
        address multisig,
        IAuthority authority,
        address user,
        uint64 role,
        address target,
        bytes4 selector1,
        bytes4 selector2,
        bytes4 selector3
    ) internal {
        bytes4[] memory _selectors = new bytes4[](3);
        _selectors[0] = selector1;
        _selectors[1] = selector2;
        _selectors[2] = selector3;

        vm.prank(multisig);
        authority.setTargetFunctionRole(target, _selectors, role);

        vm.prank(multisig);
        authority.grantRole(role, user, 0);
    }

    /// @dev todo Functions below should use several different roles instead of AccessRolesLib.HOST_ADMIN
    function setupHostMultisigAccess(Vm vm, IHost host, address multisig) internal {
        address authority = IAccessManaged(address(host)).authority();

        // --------------------------------- For simplicity use same role 5555 for ALL restricted functions in this set of tests
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = bytes4(IHost.setSettings.selector);
        selectors[1] = bytes4(IHost.setChainSettings.selector);
        selectors[2] = bytes4(IHost.updateByAdmin.selector);
        selectors[3] = bytes4(IHost.refundFor.selector);
        selectors[4] = bytes4(IHost.onReceiveCrossChainMessage.selector);
        selectors[5] = bytes4(IHost.receiveVotingResults.selector);
        selectors[6] = bytes4(IHost.validateProposal.selector);
        selectors[7] = bytes4(IHost.setContractImplementation.selector);
        selectors[8] = bytes4(IHost.deployProxy.selector);

        vm.prank(multisig);
        IAccessManager(address(authority)).setTargetFunctionRole(address(host), selectors, AccessRolesLib.HOST_ADMIN);

        vm.prank(multisig);
        IAccessManager(address(authority)).grantRole(AccessRolesLib.HOST_ADMIN, multisig, 0);
    }

    /// @dev Host should be able to set up seed, tge tokens which it deploys
    function setupHostAsAuthorityAdmin(Vm vm, IHost host, address multisig) internal {
        address authority = IAccessManaged(address(host)).authority();

        vm.prank(multisig);
        IAccessManager(address(authority)).grantRole(0, address(host), 0);
    }
}
