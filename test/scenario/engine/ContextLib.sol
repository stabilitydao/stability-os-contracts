// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Test.sol";
import {HostSetupLib} from "./HostSetupLib.sol";
import {DeployUsesCaseLib} from "../uses-cases/DeployUsesCaseLib.sol";
import {RestrictHostUtils} from "../access/RestrictHostUtils.sol";
import {EngineLib} from "./EngineLib.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";
import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {IHostCodec} from "../../../src/interfaces/IHostCodec.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {StdConfig} from "forge-std/StdConfig.sol";

library ContextLib {
    function getBaseContext(uint chainId, uint forkId) internal returns (EngineLib.BaseContext memory) {
        StdConfig configDeployed = new StdConfig("./config.d.toml", false);
        StdConfig config = new StdConfig("./config.toml", false);

        return EngineLib.BaseContext({
            configDeployed: configDeployed,
            config: config,
            chainId: chainId,
            forkId: forkId
        });
    }

    function createCore(
        Vm vm,
        uint chainId,
        uint fork,
        address validator
    ) internal returns (EngineLib.ChainConfig memory) {
        vm.selectFork(fork);

        EngineLib.BaseContext memory bc = getBaseContext(chainId, fork);
        IProxyFactory proxyFactory = IProxyFactory(bc.configDeployed.get(chainId, "PROXY_FACTORY").toAddress());
        address deployer = IOwnable(address(proxyFactory)).owner();

        vm.startPrank(deployer);
        EngineLib.ChainConfig memory core = DeployUsesCaseLib.deployCore(bc, validator);
        vm.stopPrank();

        vm.startPrank(core.multisig);
        HostSetupLib.setupHostSettings(core);
        HostSetupLib.setupHostChainSettings(chainId, core);
        HostSetupLib.setTokenImplementations(core);
        RestrictHostUtils.setupValidator(core.authority, address(core.host), validator);
        vm.stopPrank();

        return core;
    }

    function getContext(EngineLib.ChainConfig memory chain) internal returns (EngineLib.Context memory) {
        address user = address(this);
        return EngineLib.Context({
            core: chain,
            bc: getBaseContext(chain.chainId, chain.fork),
            user: user,
            multisig: chain.multisig,
            validator: chain.hostValidator
        });
    }

}