// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ContextLib} from "../engine/ContextLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {HostDaoUsesCaseLib} from "../uses-cases/HostDaoUsesCaseLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IBridgedActions} from "../../../src/interfaces/IBridgedActions.sol";
import {Test} from "forge-std/Test.sol";
import {MevBotDaoUsesCaseLib} from "../uses-cases/MevBotDaoUsesCaseLib.sol";
import {BridgedActionsUsesCaseLib} from "../uses-cases/BridgedActionsUsesCaseLib.sol";
import {BridgeSetupLib} from "../engine/BridgeSetupLib.sol";
import {LayerZeroUtils} from "../engine/LayerZeroUtils.sol";

// import {console} from "forge-std/console.sol";

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

        /// @dev Set up layer zero bridges between Ethereum and Sonic
        BridgeSetupLib.setUpOAppsSingleDVN(vm, eth, sonic, ethDvn, sonicDvn);
        LayerZeroUtils.setHostBridgePeers(vm, eth, sonic);

        /// @dev Fund validator on both chains to be able to validate proposals and register voting results
        vm.selectFork(eth.fork);
        deal(validator, 1000e18);
        vm.selectFork(sonic.fork);
        deal(validator, 1000e18);
    }

    function testCreateBridgedMevDao() public {
        address user = makeAddr("user");

        vm.selectFork(eth.fork);
        EngineLib.Context memory context = ContextLib.getContext(eth, user);
        deal(eth.host.getChainSettings().exchangeAsset, user, 1000e18);

        /// @dev Create MEV dao on ETH
        IDAOData.DaoData memory daoEth = MevBotDaoUsesCaseLib.createMevBotDao(vm, context);

        /// @dev Init params to create MEV dao on Sonic
        IBridgedActions.BridgeDaoParams memory params = IBridgedActions.BridgeDaoParams({
            symbol: daoEth.symbol,
            name: daoEth.name,
            unitIds: daoEth.unitIds,
            chainSettings: IDAOData.DaoChainSettings({
                bbRate: daoEth.chainSettings.bbRate,
                multisig: sonic.multisig // Sonic multisig is different from ETH multisig
            }),
            daoParameters: daoEth.params,
            saltContractIndices: new uint16[](0), // no salts
            salts: new bytes32[](0)
        });

        /// @dev Create MEV dao on Sonic via bridge
        BridgedActionsUsesCaseLib.bridgeDao(vm, user, daoEth.symbol, eth, sonic, params);

        //---------------------------------- Check results
        vm.selectFork(sonic.fork);
        IDAOData.DaoData memory daoSonic = sonic.dataReader.getDAO(daoEth.symbol);

        assertTrue(sonic.host.isDaoSymbolInUse(daoEth.symbol), "MEV DAO symbol should be in use on Sonic");
        assertNotEq(sonic.host.hostDaoUid(), daoEth.uid, "mev dao on sonic is not host dao");

        assertEq(daoEth.uid, daoSonic.uid, "MEV DAO UID should be the same across chains");
        assertEq(daoEth.symbol, daoSonic.symbol, "MEV DAO symbol should be the same across chains");

        assertEq(daoEth.unitIds, daoSonic.unitIds, "MEV DAO unitIds should be the same across chains");
        assertEq(daoSonic.deployer, address(0), "deployer is not initialized on bridged chain");
    }

    function testBridgeDaoParameters() public {
        address user = makeAddr("user");

        vm.selectFork(eth.fork);
        EngineLib.Context memory context = ContextLib.getContext(eth, user);
        deal(eth.host.getChainSettings().exchangeAsset, user, 1000e18);

        /// @dev Create MEV dao on ETH
        IDAOData.DaoData memory daoEth = MevBotDaoUsesCaseLib.createMevBotDao(vm, context);

        {
            /// @dev Init params to create MEV dao on Sonic
            IBridgedActions.BridgeDaoParams memory params = IBridgedActions.BridgeDaoParams({
                symbol: daoEth.symbol,
                name: daoEth.name,
                unitIds: daoEth.unitIds,
                chainSettings: IDAOData.DaoChainSettings({
                    bbRate: daoEth.chainSettings.bbRate,
                    multisig: sonic.multisig // Sonic multisig is different from ETH multisig
                }),
                daoParameters: daoEth.params,
                saltContractIndices: new uint16[](0), // no salts
                salts: new bytes32[](0)
            });

            /// @dev Create MEV dao on Sonic via bridge
            BridgedActionsUsesCaseLib.bridgeDao(vm, user, daoEth.symbol, eth, sonic, params);
        }

        //        {
        //            IDAOData.DaoParameters memory params = IDAOData.DaoParameters({
        //                vePeriod: 365 * 2,
        //                pvpFee: 100e5 * 2,
        //                minPower: 1,
        //                ttBribe: 2,
        //                recoveryShare: 3,
        //                proposalThreshold: 4,
        //                totalSupply: 15_000_000e18
        //            });
        //        }

        // todo probably we should use stored values?
    }

    function testBridgeDaoChainSettings() public {
        address user = makeAddr("user");

        vm.selectFork(eth.fork);
        EngineLib.Context memory context = ContextLib.getContext(eth, user);
        deal(eth.host.getChainSettings().exchangeAsset, user, 1000e18);

        /// @dev Create MEV dao on ETH
        IDAOData.DaoData memory daoEth = MevBotDaoUsesCaseLib.createMevBotDao(vm, context);

        {
            /// @dev Init params to create MEV dao on Sonic
            IBridgedActions.BridgeDaoParams memory params = IBridgedActions.BridgeDaoParams({
                symbol: daoEth.symbol,
                name: daoEth.name,
                unitIds: daoEth.unitIds,
                chainSettings: IDAOData.DaoChainSettings({
                    bbRate: 10,
                    multisig: sonic.multisig // Sonic multisig is different from ETH multisig
                }),
                daoParameters: daoEth.params,
                saltContractIndices: new uint16[](0), // no salts
                salts: new bytes32[](0)
            });

            /// @dev Create MEV dao on Sonic via bridge
            BridgedActionsUsesCaseLib.bridgeDao(vm, user, daoEth.symbol, eth, sonic, params);
        }

        {
            vm.selectFork(eth.fork);
            IDAOData.DaoChainSettings memory paramsSonic =
                IDAOData.DaoChainSettings({bbRate: 90, multisig: makeAddr("new multisig")});

            /// @dev Update DAO chain settings on bridged chain via bridge
            IDAOData.DaoData memory bridgedDao =
                BridgedActionsUsesCaseLib.bridgeDaoChainSettings(vm, user, daoEth.symbol, eth, sonic, paramsSonic);

            assertEq(bridgedDao.chainSettings.bbRate, 90, "bbRate is updated");
            assertEq(bridgedDao.chainSettings.multisig, makeAddr("new multisig"), "multisig is updated");
        }
    }

    //region --------------------------------- Internal functions
    function _createCoreOnSonic(
        IDAOData.DaoData memory daoEth,
        uint forkSonic
    ) internal returns (EngineLib.ChainConfig memory) {
        // @dev Prepare init
        IHost.HostInitPayload memory init = IHost.HostInitPayload({
            usedSymbols: new string[](0),
            hostVersion: "2026.02.23.1",
            daoHost: IHost.DaoHostInitParams({
                uid: eth.host.hostDaoUid(), symbol: daoEth.symbol, name: daoEth.name, unitIds: daoEth.unitIds
            })
        });

        // @dev create host on Sonic
        return ContextLib.createCore(vm, 146, forkSonic, validator, init);
    }
    //endregion --------------------------------- Internal functions
}
