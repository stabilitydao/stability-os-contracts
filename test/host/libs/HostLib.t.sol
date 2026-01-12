// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HostLib} from "../../../src/host/libs/HostLib.sol";

contract HostLibTest is Test {
    uint private constant SONIC_FORK_BLOCK = 52228979; // Oct-28-2025 01:14:21 PM +UTC
    uint private constant AVALANCHE_FORK_BLOCK = 71037861; // Oct-28-2025 13:17:17 UTC

    function testGenerateDaoUid() public {
        uint forkSonic = vm.createFork(vm.envString("SONIC_RPC_URL"), SONIC_FORK_BLOCK);
        uint forkAvalanche = vm.createFork(vm.envString("AVALANCHE_RPC_URL"), AVALANCHE_FORK_BLOCK);

        uint uid1a;
        uint uid2a;

        uint uid1b;
        uint uid2b;

        {
            uint snapshot = vm.snapshotState();
            vm.selectFork(forkSonic);
            HostLib.OsStorage storage $ = HostLib.getOsStorage();

            uid1a = HostLib.generateDaoUid($);
            uid2a = HostLib.generateDaoUid($);
            vm.revertToState(snapshot);
        }

        {
            uint snapshot = vm.snapshotState();
            vm.selectFork(forkAvalanche);
            HostLib.OsStorage storage $ = HostLib.getOsStorage();

            uid1b = HostLib.generateDaoUid($);
            uid2b = HostLib.generateDaoUid($);
            vm.revertToState(snapshot);
        }

        assertNotEq(uid1a, uid2a, "DAO UIDs should be unique");
        assertNotEq(uid1b, uid2b, "DAO UIDs should be unique");
        assertNotEq(uid1a, uid1b, "DAO UIDs should be unique across forks");
        assertNotEq(uid2a, uid2b, "DAO UIDs should be unique across forks");
    }
}
