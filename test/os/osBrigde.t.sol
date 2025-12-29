// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OsUtilsLib} from "./utils/OsUtilsLib.sol";
import {OSBridge} from "../../src/os/OSBridge.sol";
import {BridgeTestLib} from "../../test/os/libs/BridgeTestLib.sol";

contract OsBridgeTest is Test, OsUtilsLib {
    uint private constant SONIC_FORK_BLOCK = 52228979; // Oct-28-2025 01:14:21 PM +UTC
    uint private constant AVALANCHE_FORK_BLOCK = 71037861; // Oct-28-2025 13:17:17 UTC
    uint private constant PLASMA_FORK_BLOCK = 5398928; // Nov-5-2025 07:38:59 UTC

    address private constant TEST_DELEGATOR = address(0x9999);

    BridgeTestLib.ChainConfig internal sonic;
    BridgeTestLib.ChainConfig internal avalanche;
    BridgeTestLib.ChainConfig internal plasma;

    constructor() {
        {
            uint forkSonic = vm.createFork(vm.envString("SONIC_RPC_URL"), SONIC_FORK_BLOCK);
            uint forkAvalanche = vm.createFork(vm.envString("AVALANCHE_RPC_URL"), AVALANCHE_FORK_BLOCK);
            uint forkPlasma = vm.createFork(vm.envString("PLASMA_RPC_URL"), PLASMA_FORK_BLOCK);

            sonic = BridgeTestLib.createConfigSonic(vm, forkSonic, TEST_DELEGATOR);
            avalanche = BridgeTestLib.createConfigAvalanche(vm, forkAvalanche, TEST_DELEGATOR);
            plasma = BridgeTestLib.createConfigPlasma(vm, forkPlasma, TEST_DELEGATOR);
        }

        // ------------------- Create adapter and bridged token
        sonic.osBridge = BridgeTestLib.createOSBridge(vm, sonic);
        avalanche.osBridge = BridgeTestLib.createOSBridge(vm, avalanche);
        plasma.osBridge = BridgeTestLib.createOSBridge(vm, plasma);

        // ------------------- Set up Sonic:Avalanche
        BridgeTestLib.setUpSonicAvalanche(vm, sonic, avalanche);

        // ------------------- Set up Sonic:Plasma
        BridgeTestLib.setUpSonicPlasma(vm, sonic, plasma);

        // ------------------- Set up Avalanche:Plasma
        BridgeTestLib.setUpAvalanchePlasma(vm, avalanche, plasma);
    }
}
