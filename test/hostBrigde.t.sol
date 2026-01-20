// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {Vm, Test} from "forge-std/Test.sol";
import {HostUtilsLib} from "./utils/HostUtilsLib.sol";
import {BridgeTestLib} from "../test/utils/BridgeTestLib.sol";
import {IHost} from "../src/interfaces/IHost.sol";
import {IHostProxyFactory} from "../src/interfaces/IHostProxyFactory.sol";
import {IHostAccessManager} from "../src/interfaces/IHostAccessManager.sol";
import {IDAOData} from "../src/interfaces/IDAOData.sol";
import {SonicConstantsLib} from "../chains/SonicConstantsLib.sol";
import {PlasmaConstantsLib} from "../chains/PlasmaConstantsLib.sol";
import {AvalancheConstantsLib} from "../chains/AvalancheConstantsLib.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReceiver.sol";
import {IOAppReceiver} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HostBridgeTest is Test {
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

        // ------------------- Set up Sonic:Avalanche
        BridgeTestLib.setUpSonicAvalanche(vm, sonic, avalanche);

        // ------------------- Set up Sonic:Plasma
        BridgeTestLib.setUpSonicPlasma(vm, sonic, plasma);

        // ------------------- Set up Avalanche:Plasma
        BridgeTestLib.setUpAvalanchePlasma(vm, avalanche, plasma);
    }

    function testStorageLocation() internal pure {
        console.log("keccak256(abi.encode(uint(keccak256(erc7201:stability.host-contracts.HostBridge))))");
        console.logBytes32(
            keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostBridge")) - 1))
                & ~bytes32(uint(0xff))
        );
    }

    function testInitialization() public {
        vm.recordLogs();

        // ----------------------------- set up sonic
        vm.selectFork(sonic.fork);
        IHost hostSonic = IHost(IHostAccessManager(sonic.authority).HOST());
        HostUtilsLib.setupHostInstance(
            vm,
            SonicConstantsLib.MULTISIG,
            IHostAccessManager(sonic.authority),
            IHostProxyFactory(sonic.hostFactory),
            hostSonic
        );
        BridgeTestLib.setupHostBridgeAndHostFactory(vm, hostSonic, sonic, plasma, avalanche);

        // ----------------------------- set up avalanche
        vm.selectFork(avalanche.fork);
        IHost hostAvax = IHost(IHostAccessManager(avalanche.authority).HOST());
        HostUtilsLib.setupHostInstance(
            vm,
            AvalancheConstantsLib.MULTISIG,
            IHostAccessManager(avalanche.authority),
            IHostProxyFactory(avalanche.hostFactory),
            hostAvax
        );
        BridgeTestLib.setupHostBridgeAndHostFactory(vm, hostAvax, avalanche, sonic, plasma);

        // ----------------------------- set up plasma
        vm.selectFork(plasma.fork);
        IHost hostPlasma = IHost(IHostAccessManager(plasma.authority).HOST());
        HostUtilsLib.setupHostInstance(
            vm,
            PlasmaConstantsLib.MULTISIG,
            IHostAccessManager(plasma.authority),
            IHostProxyFactory(plasma.hostFactory),
            hostPlasma
        );
        BridgeTestLib.setupHostBridgeAndHostFactory(vm, hostPlasma, plasma, sonic, avalanche);

        // ----------------------------- create DAO on Sonic
        vm.selectFork(sonic.fork);
        _dealAndApprove(hostSonic);
        IDAOData.DaoData memory dao1 = HostUtilsLib.createAliensDao(vm, hostSonic);
        console.log("done createAliensDao");

        { // ------------------------- process cross chain events: Sonic -> Avalanche, Plasma
            Vm.Log[] memory logs = vm.getRecordedLogs();
            _processCrossChainMessages(logs, sonic, avalanche);
            _processCrossChainMessages(logs, sonic, plasma);
        }

        // ----------------------------- create DAO on Avalanche
        vm.selectFork(avalanche.fork);
        _dealAndApprove(hostAvax);
        IDAOData.DaoData memory dao2 = HostUtilsLib.createApesDao(vm, hostAvax);
        console.log("done createApesDao");

        { // ------------------------- process cross chain events: Avalanche -> Sonic, Plasma
            Vm.Log[] memory logs = vm.getRecordedLogs();
            _processCrossChainMessages(logs, avalanche, sonic);
            _processCrossChainMessages(logs, avalanche, plasma);
        }

        // ----------------------------- create DAO on Plasma
        vm.selectFork(plasma.fork);
        _dealAndApprove(hostPlasma);
        IDAOData.DaoData memory dao3 = HostUtilsLib.createDaoMachines(vm, hostPlasma);

        { // ------------------------- process cross chain events: Plasma -> Sonic, Avalanche
            Vm.Log[] memory logs = vm.getRecordedLogs();
            _processCrossChainMessages(logs, plasma, sonic);
            _processCrossChainMessages(logs, plasma, avalanche);
        }

        // ----------------------------- Check results of cross-chain message exchange
        vm.selectFork(sonic.fork);
        assertEq(hostSonic.isDaoSymbolInUse(dao1.symbol), true, "Sonic: dao1 symbol");
        assertEq(hostSonic.isDaoSymbolInUse(dao2.symbol), true, "Sonic: dao2 symbol");
        assertEq(hostSonic.isDaoSymbolInUse(dao3.symbol), true, "Sonic: dao3 symbol");

        vm.selectFork(avalanche.fork);
        assertEq(hostAvax.isDaoSymbolInUse(dao1.symbol), true, "Avax: dao1 symbol");
        assertEq(hostAvax.isDaoSymbolInUse(dao2.symbol), true, "Avax: dao2 symbol");
        assertEq(hostAvax.isDaoSymbolInUse(dao3.symbol), true, "Avax; dao3 symbol");

        vm.selectFork(plasma.fork);
        assertEq(hostPlasma.isDaoSymbolInUse(dao1.symbol), true, "Plasma: dao1 symbol");
        assertEq(hostPlasma.isDaoSymbolInUse(dao2.symbol), true, "Plasma: dao2 symbol");
        assertEq(hostPlasma.isDaoSymbolInUse(dao3.symbol), true, "Plasma: dao3 symbol");
    }

    function _processCrossChainMessages(
        Vm.Log[] memory logs,
        BridgeTestLib.ChainConfig memory from,
        BridgeTestLib.ChainConfig memory to
    ) internal {
        vm.selectFork(to.fork);
        (bytes memory message,) = BridgeTestLib._extractSendMessage(logs);
        Origin memory origin =
            Origin({srcEid: from.endpointId, sender: bytes32(uint(uint160(address(from.hostBridge)))), nonce: 1});

        vm.prank(to.endpoint);
        IOAppReceiver(to.hostBridge)
            .lzReceive(
                origin,
                bytes32(0), // guid: actual value doesn't matter
                message,
                address(0), // executor
                "" // extraData
            );
    }

    /// @notice user should pay for DAO-creation
    function _dealAndApprove(IHost os_) internal {
        address exchangeAsset = os_.getChainSettings().exchangeAsset;
        uint amount = os_.getSettings().priceDao;
        deal(exchangeAsset, address(this), amount);
        IERC20(exchangeAsset).approve(address(os_), amount);
    }
}
