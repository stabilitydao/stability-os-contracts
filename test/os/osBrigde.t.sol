// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {OsUtilsLib} from "./utils/OsUtilsLib.sol";
import {OSBridge} from "../../src/os/OSBridge.sol";
import {BridgeTestLib} from "../../test/os/utils/BridgeTestLib.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IOS} from "../../src/interfaces/IOS.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {SonicConstantsLib} from "../../chains/SonicConstantsLib.sol";
import {PlasmaConstantsLib} from "../../chains/PlasmaConstantsLib.sol";
import {AvalancheConstantsLib} from "../../chains/AvalancheConstantsLib.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReceiver.sol";
import {IOAppReceiver} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReceiver.sol";

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

    function testInitialization() public {
        // ----------------------------- create DAO on Sonic
        vm.selectFork(sonic.fork);
        IOS.OsInitPayload memory init;
        IOS osSonic = OsUtilsLib.createOsInstance(vm, SonicConstantsLib.MULTISIG, IAccessManager(sonic.authority), init);
        OsUtilsLib.setupOsBridge(vm, osSonic, sonic, plasma, avalanche);
        ITokenomics.DaoData memory dao1 = OsUtilsLib.createAliensDao(osSonic);

        // ----------------------------- create DAO on Avalanche
        vm.selectFork(avalanche.fork);
        init.usedSymbols = new string[](1);
        init.usedSymbols[0] = dao1.symbol;
        IOS osAvax = OsUtilsLib.createOsInstance(vm, AvalancheConstantsLib.MULTISIG, IAccessManager(avalanche.authority), init);
        OsUtilsLib.setupOsBridge(vm, osAvax, avalanche, sonic, plasma);

        vm.recordLogs();
        ITokenomics.DaoData memory dao2 = OsUtilsLib.createApesDao(osAvax);
        { // ------------------------- process cross chain events: Sonic -> Avalanche
            (bytes memory message,) = BridgeTestLib._extractSendMessage(vm.getRecordedLogs());
            Origin memory origin = Origin({
                srcEid: SonicConstantsLib.LAYER_ZERO_V2_ENDPOINT_ID,
                sender: bytes32(uint(uint160(address(osSonic)))),
                nonce: 1
            });
            vm.prank(avalanche.endpoint);
            IOAppReceiver(avalanche.osBridge).lzReceive(
                origin,
                bytes32(0), // guid: actual value doesn't matter
                message,
                address(0), // executor
                "" // extraData
            );
        }

        // ----------------------------- create DAO on Plasma
        vm.selectFork(plasma.fork);
        init.usedSymbols = new string[](2);
        init.usedSymbols[0] = dao1.symbol;
        init.usedSymbols[1] = dao2.symbol;
        IOS osPlasma = OsUtilsLib.createOsInstance(vm, PlasmaConstantsLib.MULTISIG, IAccessManager(plasma.authority), init);
        OsUtilsLib.setupOsBridge(vm, osPlasma, plasma, sonic, avalanche);
        ITokenomics.DaoData memory dao3 = OsUtilsLib.createDaoMachines(osPlasma);
        // todo process cross chain events

        // ----------------------------- Check results of cross-chain message exchange
        vm.selectFork(sonic.fork);
        assertEq(osSonic.isDaoSymbolInUse(dao1.symbol), true, "Sonic: dao1 symbol");
        assertEq(osSonic.isDaoSymbolInUse(dao2.symbol), true, "Sonic: dao2 symbol");
        assertEq(osSonic.isDaoSymbolInUse(dao3.symbol), true, "Sonic: dao3 symbol");

        vm.selectFork(avalanche.fork);
        assertEq(osAvax.isDaoSymbolInUse(dao1.symbol), true, "Avax: dao1 symbol");
        assertEq(osAvax.isDaoSymbolInUse(dao2.symbol), true, "Avax: dao2 symbol");
        assertEq(osAvax.isDaoSymbolInUse(dao3.symbol), true, "Avax:; dao3 symbol");

        vm.selectFork(plasma.fork);
        assertEq(osPlasma.isDaoSymbolInUse(dao1.symbol), true, "Plasma: dao1 symbol");
        assertEq(osPlasma.isDaoSymbolInUse(dao2.symbol), true, "Plasma: dao2 symbol");
        assertEq(osPlasma.isDaoSymbolInUse(dao3.symbol), true, "Plasma: dao3 symbol");
    }


}
