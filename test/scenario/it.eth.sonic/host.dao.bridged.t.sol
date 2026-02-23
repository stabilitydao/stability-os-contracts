// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ContextLib} from "../engine/ContextLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {HostDaoUsesCaseLib} from "../uses-cases/HostDaoUsesCaseLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {Test} from "forge-std/Test.sol";
import {PrintUtilsLib} from "../../utils/PrintUtilsLib.sol";
// import {console} from "forge-std/console.sol";
// import {PrintUtilsLib} from "../../utils/PrintUtilsLib.sol";

/// @dev Uses cases for DAO "HOST" on two chains: Ethereum mainnet and Sonic (via bridge)
contract HostDaoBridgedUsesCaseTest is Test {
    uint internal constant MAINNET_FORK_BLOCK = 24481863; // Feb-18-2026 06:15:47 AM +UTC
    uint internal constant SONIC_FORK_BLOCK = 63323292; // Feb-20-2026 01:31:24 PM +UTC

    StdConfig internal config;
    StdConfig internal configDeployed;

    EngineLib.ChainConfig internal eth;
    uint internal forkSonic;

    /// @dev Backend validator to validate proposals and register voting results
    address internal validator;
    address internal multisig;

    string internal HOST_DAO_SYMBOL;

    constructor() {
        uint forkEth = vm.createFork(vm.envString("ETHEREUM_RPC_URL"), MAINNET_FORK_BLOCK);
        forkSonic = vm.createFork(vm.envString("SONIC_RPC_URL"), SONIC_FORK_BLOCK);
        validator = makeAddr("validator");

        // @dev create host on Ethereum (initial chain)
        eth = ContextLib.createCore(vm, 1, forkEth, validator);

        // @dev Provide liquidity for HOST DAO creation on Ethereum
        deal(eth.host.getChainSettings().exchangeAsset, address(this), 1000e18);

        // @dev create HOST DAO
        HOST_DAO_SYMBOL = HostDaoUsesCaseLib.createHostDao(vm, ContextLib.getContext(eth, address(this))).symbol;
    }

    function testCreateHostDao() public {
        vm.selectFork(eth.fork);
        IDAOData.DaoData memory daoEth = eth.dataReader.getDAO(HOST_DAO_SYMBOL);

        // ----------------------------- Create DAO HOST on Sonic
        EngineLib.ChainConfig memory sonic = _createCoreOnSonic(daoEth);

        // ---------------------------------- Check results
        vm.selectFork(sonic.fork);
        IDAOData.DaoData memory daoSonic = sonic.dataReader.getDAO(HOST_DAO_SYMBOL);

        assertTrue(sonic.host.isDaoSymbolInUse(HOST_DAO_SYMBOL), "HOST DAO symbol should be in use on Sonic");
        assertEq(sonic.host.hostDaoUid(), daoEth.uid, "host dao on sonic is expected");

        assertEq(daoEth.uid, daoSonic.uid, "HOST DAO UID should be the same across chains");
        assertEq(daoEth.symbol, daoSonic.symbol, "HOST DAO symbol should be the same across chains");

        assertEq(daoEth.unitIds, daoSonic.unitIds, "HOST DAO unitIds should be the same across chains");
    }

    //region --------------------------------- Internal functions
    function _createCoreOnSonic(IDAOData.DaoData memory daoEth) internal returns (EngineLib.ChainConfig memory sonic) {
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
