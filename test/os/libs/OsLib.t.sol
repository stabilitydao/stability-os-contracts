// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OsLib} from "../../../src/os/libs/OsLib.sol";

contract OsLibTest is Test {
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
            OsLib.OsStorage storage $ = OsLib.getOsStorage();

            uid1a = OsLib.generateDaoUid($);
            uid2a = OsLib.generateDaoUid($);
            vm.revertToState(snapshot);
        }

        {
            uint snapshot = vm.snapshotState();
            vm.selectFork(forkAvalanche);
            OsLib.OsStorage storage $ = OsLib.getOsStorage();

            uid1b = OsLib.generateDaoUid($);
            uid2b = OsLib.generateDaoUid($);
            vm.revertToState(snapshot);
        }

        assertNotEq(uid1a, uid2a, "DAO UIDs should be unique");
        assertNotEq(uid1b, uid2b, "DAO UIDs should be unique");
        assertNotEq(uid1a, uid1b, "DAO UIDs should be unique across forks");
        assertNotEq(uid2a, uid2b, "DAO UIDs should be unique across forks");
    }
}
