// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Test.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";

library HostSetupUtils {
    /// @dev set asset as whitelisted in Host by admin
    function whitelistAsset(Vm vm, address admin, IHost host, address asset_) internal {
        address[] memory assets = new address[](1);
        assets[0] = address(asset_);

        vm.prank(admin);
        host.whitelistAssets(assets, true);
    }
}
