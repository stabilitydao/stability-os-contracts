// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HostConfigLib} from "../../src/libs/HostConfigLib.sol";

contract HostConfigLibTest is Test {
    uint private constant SONIC_FORK_BLOCK = 52228979; // Oct-28-2025 01:14:21 PM +UTC
    uint private constant AVALANCHE_FORK_BLOCK = 71037861; // Oct-28-2025 13:17:17 UTC

    function testGlobalStorageLocation() public pure {
        assertEq(
            keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostConfigLib.global")) - 1))
                & ~bytes32(uint(0xff)),
            HostConfigLib.HOST_GLOBAL_STORAGE_LOCATION,
            "HOST_GLOBAL_STORAGE_LOCATION"
        );
    }

    function testChainStorageLocation() public pure {
        assertEq(
            keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostConfigLib.chain")) - 1))
                & ~bytes32(uint(0xff)),
            HostConfigLib.HOST_CHAIN_STORAGE_LOCATION,
            "HOST_CHAIN_STORAGE_LOCATION"
        );
    }
}
