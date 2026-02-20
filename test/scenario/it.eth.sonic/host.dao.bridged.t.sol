// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ContextLib} from "../engine/ContextLib.sol";
import {BridgeTestLib} from "../../utils/BridgeTestLib.sol";
import {DeployUsesCaseLib} from "../uses-cases/DeployUsesCaseLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {HostDaoUsesCaseLib} from "../uses-cases/HostDaoUsesCaseLib.sol";
import {HostSetupLib} from "../engine/HostSetupLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {RestrictHostUtils} from "../access/RestrictHostUtils.sol";
import {SampleDataLib} from "../../utils/SampleDataLib.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
// import {PrintUtilsLib} from "../../utils/PrintUtilsLib.sol";

/// @dev Uses cases for DAO "HOST" on two chains: Ethereum mainnet and Sonic (via bridge)
contract HostDaoBridgedUsesCaseTest is Test {
    uint internal constant MAINNET_FORK_BLOCK = 24481863; // Feb-18-2026 06:15:47 AM +UTC
    uint internal constant SONIC_FORK_BLOCK = 63323292; // Feb-20-2026 01:31:24 PM +UTC

    StdConfig internal config;
    StdConfig internal configDeployed;

    EngineLib.ChainConfig internal eth;
    EngineLib.ChainConfig internal sonic;

    /// @dev Backend validator to validate proposals and register voting results
    address internal validator;
    address internal multisig;

    constructor() {
        uint forkEth = vm.createFork(vm.envString("ETHEREUM_RPC_URL"), MAINNET_FORK_BLOCK);
        uint forkSonic = vm.createFork(vm.envString("SONIC_RPC_URL"), SONIC_FORK_BLOCK);
        validator = makeAddr("validator");
        eth = ContextLib.createCore(vm, 1, forkEth, validator);
        sonic = ContextLib.createCore(vm, 146, forkSonic, validator);
    }

    /// @dev 1. Create DAO HOST on Ethereum
    /// @dev 2. Create DAO HOST on Sonic
    function testCreateHostDao() public {
        // ----------------------------- Create DAO HOST on Ethereum
        vm.selectFork(eth.fork);
        EngineLib.Context memory context = ContextLib.getContext(eth);
        deal(eth.host.getChainSettings().exchangeAsset, address(this), 1000e18);

        IDAOData.DaoData memory dao = HostDaoUsesCaseLib.createHostDao(vm, context);

        // ----------------------------- Create DAO HOST on Sonic

    }
}
