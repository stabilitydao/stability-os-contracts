// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ContextLib} from "../engine/ContextLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {HostDaoUsesCaseLib} from "../uses-cases/HostDaoUsesCaseLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IBridgedActions} from "../../../src/interfaces/IBridgedActions.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {Test} from "forge-std/Test.sol";
import {PrintUtilsLib} from "../../utils/PrintUtilsLib.sol";
import {MevBotDaoUsesCaseLib} from "../uses-cases/MevBotDaoUsesCaseLib.sol";
import {BridgedActionsUsesCaseLib} from "../uses-cases/BridgedActionsUsesCaseLib.sol";
import {BridgeSetupLib} from "../engine/BridgeSetupLib.sol";
import {LayerZeroUtils} from "../engine/LayerZeroUtils.sol";
import {console} from "forge-std/console.sol";
// import {PrintUtilsLib} from "../../utils/PrintUtilsLib.sol";

/// @dev Uses cases for DAO "MEV" on two chains: Ethereum mainnet and Sonic (via bridge)
contract MevDaoBridgedUsesCaseTest is Test {
    uint internal constant MAINNET_FORK_BLOCK = 24481863; // Feb-18-2026 06:15:47 AM +UTC
    uint internal constant SONIC_FORK_BLOCK = 63323292; // Feb-20-2026 01:31:24 PM +UTC

    EngineLib.ChainConfig internal eth;
    EngineLib.ChainConfig internal sonic;

    /// @dev Backend validator to validate proposals and register voting results
    address internal validator;
    address internal multisig;

    constructor() {
        uint forkEth = vm.createFork(vm.envString("ETHEREUM_RPC_URL"), MAINNET_FORK_BLOCK);
        uint forkSonic = vm.createFork(vm.envString("SONIC_RPC_URL"), SONIC_FORK_BLOCK);

        /// @dev Backend validator to validate proposals and register voting results
        validator = makeAddr("validator");

        /// @dev create host on Ethereum (initial chain)
        eth = ContextLib.createCore(vm, 1, forkEth, validator);

        /// @dev Provide liquidity for HOST DAO creation on Ethereum
        deal(eth.host.getChainSettings().exchangeAsset, address(this), 1000e18);

        EngineLib.Context memory ctxEth = ContextLib.getContext(eth, address(this));

        /// @dev create HOST DAO
        string memory hostDaoSymbol = HostDaoUsesCaseLib.createHostDao(vm, ctxEth).symbol;

        /// @dev Create DAO HOST on Sonic
        sonic = _createCoreOnSonic(eth.dataReader.getDAO(hostDaoSymbol), forkSonic);

        vm.selectFork(eth.fork);
        address ethDvn = ctxEth.bc.config.get(eth.chainId, "LAYER_ZERO_V2_DVN_LAYER_ZERO_LABS_PUSH").toAddress();
        address sonicDvn = ctxEth.bc.config.get(sonic.chainId, "LAYER_ZERO_V2_DVN_LAYER_ZERO_LABS_PUSH").toAddress();

//        vm.selectFork(eth.fork);
//        console.log("hostBridge eth", eth.host.getChainSettings().hostBridge);
//        vm.selectFork(sonic.fork);
//        console.log("hostBridge sonic", sonic.host.getChainSettings().hostBridge);

        /// @dev Set up layer zero bridges between Ethereum and Sonic
        BridgeSetupLib.setUpOAppsSingleDVN(vm, eth, sonic, ethDvn, sonicDvn);
        LayerZeroUtils.setHostBridgePeers(vm, eth, sonic);

        /// @dev Fund validator on both chains to be able to validate proposals and register voting results
        vm.selectFork(eth.fork);
        deal(validator, 1000e18);
        vm.selectFork(sonic.fork);
        deal(validator, 1000e18);

    }

    function testCreateHostDao() public {
//        PrintUtilsLib.printChainConfig(eth);
//        PrintUtilsLib.printChainConfig(sonic);

//        {
//            vm.selectFork(eth.fork);
//            EngineLib.Context memory ctxEth = ContextLib.getContext(eth, address(this));
//
//            address ethDvn = ctxEth.bc.config.get(eth.chainId, "LAYER_ZERO_V2_DVN_LAYER_ZERO_LABS_PUSH").toAddress();
//            address sonicDvn = ctxEth.bc.config.get(sonic.chainId, "LAYER_ZERO_V2_DVN_LAYER_ZERO_LABS_PUSH").toAddress();
//            BridgeSetupLib.setUpOAppsSingleDVN(vm, eth, sonic, ethDvn, sonicDvn);
//            LayerZeroUtils.setHostBridgePeers(vm, eth, sonic);
//        }

        address user = makeAddr("user");

        vm.selectFork(eth.fork);
        EngineLib.Context memory context = ContextLib.getContext(eth, user);
        deal(eth.host.getChainSettings().exchangeAsset, user, 1000e18);

        /// @dev Create MEV dao on ETH
        IDAOData.DaoData memory dao = MevBotDaoUsesCaseLib.createMevBotDao(vm, context);

        IBridgedActions.BridgeDaoParams memory params = IBridgedActions.BridgeDaoParams({
            symbol: dao.symbol,
            name: dao.name,
            unitIds: dao.unitIds,
            chainSettings: IDAOData.DaoChainSettings({
                bbRate: dao.chainSettings.bbRate,
                multisig: sonic.multisig // Sonic multisig is different from ETH multisig
            }),
            daoParameters: dao.params,
            saltContractIndices: new uint16[](0), // no salts
            salts: new bytes32[](0)
        });
        BridgedActionsUsesCaseLib.bridgeDao(vm, user, dao.symbol, eth, sonic, params);
    }

    //region --------------------------------- Internal functions
    function _createCoreOnSonic(IDAOData.DaoData memory daoEth, uint forkSonic) internal returns (EngineLib.ChainConfig memory) {
        // @dev Prepare init
        IHost.HostInitPayload memory init = IHost.HostInitPayload({
            usedSymbols: new string[](0),
            hostVersion: "2026.02.23.1",
            daoHost: IHost.DaoHostInitParams({
                uid: eth.host.hostDaoUid(),
                symbol: daoEth.symbol,
                name: daoEth.name,
                unitIds: daoEth.unitIds
            })
        });

        // @dev create host on Sonic
        return ContextLib.createCore(vm, 146, forkSonic, validator, init);
    }
    //endregion --------------------------------- Internal functions
}
