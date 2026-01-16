// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HostLib} from "../../src/libs/HostLib.sol";
// import {console} from "forge-std/console.sol";

contract HostLibTest is Test {
    uint private constant SONIC_FORK_BLOCK = 52228979; // Oct-28-2025 01:14:21 PM +UTC
    uint private constant AVALANCHE_FORK_BLOCK = 71037861; // Oct-28-2025 13:17:17 UTC

    function testStorageLocation() public pure {
        assertEq(
            keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.Host")) - 1)) & ~bytes32(uint(0xff)),
            HostLib.HOST_STORAGE_LOCATION,
            "HOST_STORAGE_LOCATION"
        );
    }

    function testDaoUid() public {
        uint forkSonic = vm.createFork(vm.envString("SONIC_RPC_URL"), SONIC_FORK_BLOCK);
        uint forkAvalanche = vm.createFork(vm.envString("AVALANCHE_RPC_URL"), AVALANCHE_FORK_BLOCK);

        uint uid1a;
        uint uid2a;

        uint uid1b;
        uint uid2b;

        bool[4] memory first;

        {
            uint snapshot = vm.snapshotState();
            vm.selectFork(forkSonic);
            HostLib.setupDaoCounter(); // emulate constructor call
            HostLib.HostStorage storage $ = HostLib.getHostStorage();

            (uid1a, first[0]) = HostLib.generateDaoUid($);
            (uid2a, first[1]) = HostLib.generateDaoUid($);
            vm.revertToState(snapshot);
        }

        {
            uint snapshot = vm.snapshotState();
            vm.selectFork(forkAvalanche);
            HostLib.setupDaoCounter(); // emulate constructor call
            HostLib.HostStorage storage $ = HostLib.getHostStorage();

            (uid1b, first[2]) = HostLib.generateDaoUid($);
            (uid2b, first[3]) = HostLib.generateDaoUid($);
            vm.revertToState(snapshot);
        }

        assertNotEq(uid1a, uid2a, "DAO UIDs should be unique 1");
        assertNotEq(uid1b, uid2b, "DAO UIDs should be unique 2");
        assertNotEq(uid1a, uid1b, "DAO UIDs should be unique across forks 1");
        assertNotEq(uid2a, uid2b, "DAO UIDs should be unique across forks 2");

        assertEq(first[0], true, "First DAO on Sonic should be first");
        assertEq(first[1], false, "Second DAO on Sonic should not be first");
        assertEq(first[2], true, "First DAO on Avalanche should be first");
        assertEq(first[3], false, "Second DAO on Avalanche should not be first");
    }

    function testGenerateDaoUid() public view {
        uint uid1;
        {
            uint gas = gasleft();
            uid1 = HostLib.generateDaoUid(1, 1);
            uint gasUsed = gas - gasleft();
            assertLt(gasUsed, 200, "generateDaoUid uses less than 200 gas");
        }

        {
            uint uid11 = uint(keccak256(abi.encodePacked(uint(1), uint(1))));
            assertEq(uid1, uid11, "EfficientHashLib gives same results as keccak256");
        }

        uint uid2 = HostLib.generateDaoUid(1, 2);
        uint uid3 = HostLib.generateDaoUid(2, 1);

        assertNotEq(uid1, uid2, "uid1 != uid2");
        assertNotEq(uid1, uid3, "uid1 != uid3");
        assertNotEq(uid2, uid3, "uid2 != uid3");
    }

    function testGetDaoHash() public view {
        uint uid1;
        {
            uint gas = gasleft();
            uid1 = HostLib.getDaoHash(1, 1);
            uint gasUsed = gas - gasleft();
            assertLt(gasUsed, 200, "getDaoHash uses less than 200 gas");
        }

        {
            uint uid11 = uint(keccak256(abi.encodePacked(uint(1), uint(1))));
            assertEq(uid1, uid11, "EfficientHashLib gives same results as keccak256");
        }

        uint uid2 = HostLib.getDaoHash(1, 2);
        uint uid3 = HostLib.getDaoHash(2, 1);

        assertNotEq(uid1, uid2, "uid1 != uid2");
        assertNotEq(uid1, uid3, "uid1 != uid3");
        assertNotEq(uid2, uid3, "uid2 != uid3");
    }

    function testGetIndexKey() public view {
        uint uid1;
        {
            uint gas = gasleft();
            uid1 = uint(HostLib.getIndexKey(1, 1));
            uint gasUsed = gas - gasleft();
            assertLt(gasUsed, 200, "getIndexKey uses less than 200 gas");
        }

        {
            uint uid11 = uint(keccak256(abi.encodePacked(uint(1), uint(1))));
            assertEq(uid1, uid11, "EfficientHashLib gives same results as keccak256");
        }

        uint uid2 = uint(HostLib.getIndexKey(1, 2));
        uint uid3 = uint(HostLib.getIndexKey(2, 1));

        assertNotEq(uid1, uid2, "uid1 != uid2");
        assertNotEq(uid1, uid3, "uid1 != uid3");
        assertNotEq(uid2, uid3, "uid2 != uid3");
    }

    function testGetKey2() public view {
        uint uid1;
        {
            uint gas = gasleft();
            uid1 = uint(HostLib.getKey(1, 1));
            uint gasUsed = gas - gasleft();
            assertLt(gasUsed, 200, "getKey uses less than 200 gas");
        }

        {
            uint uid11 = uint(keccak256(abi.encodePacked(uint(1), uint(1))));
            assertEq(uid1, uid11, "EfficientHashLib gives same results as keccak256");
        }

        uint uid2 = uint(HostLib.getKey(1, 2));
        uint uid3 = uint(HostLib.getKey(2, 1));

        assertNotEq(uid1, uid2, "uid1 != uid2");
        assertNotEq(uid1, uid3, "uid1 != uid3");
        assertNotEq(uid2, uid3, "uid2 != uid3");
    }

    function testGetKey3() public view {
        uint uid1;
        {
            uint gas = gasleft();
            uid1 = uint(HostLib.getKey(1, 1, 1));
            uint gasUsed = gas - gasleft();
            assertLt(gasUsed, 250, "getKey uses less than 200 gas");
        }

        {
            uint uid11 = uint(keccak256(abi.encodePacked(uint(1), uint(1), uint(1))));
            assertEq(uid1, uid11, "EfficientHashLib gives same results as keccak256");
        }

        uint uid2 = uint(HostLib.getKey(1, 1, 2));
        uint uid3 = uint(HostLib.getKey(1, 2, 1));
        uint uid4 = uint(HostLib.getKey(2, 1, 1));

        assertNotEq(uid1, uid2, "uid1 != uid2");
        assertNotEq(uid1, uid3, "uid1 != uid3");
        assertNotEq(uid1, uid3, "uid1 != uid4");
        assertNotEq(uid2, uid3, "uid2 != uid3");
        assertNotEq(uid2, uid4, "uid2 != uid4");
        assertNotEq(uid3, uid4, "uid3 != uid4");
    }
}
