// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Test.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";

library AuthorityAccessUtils {
    /// @dev Get Authority from Host
    function getAuthority(IHost host) internal view returns (IAuthority) {
        return IAuthority(IAccessManaged(address(host)).authority());
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
}
