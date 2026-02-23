// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Test.sol";
import {HostSetupLib} from "./HostSetupLib.sol";
import {DeployUsesCaseLib} from "../uses-cases/DeployUsesCaseLib.sol";
import {RestrictHostUtils} from "../access/RestrictHostUtils.sol";
import {EngineLib} from "./EngineLib.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {StdConfig} from "forge-std/StdConfig.sol";

library ContextLib {
    function getBaseContext(uint chainId, uint forkId) internal returns (EngineLib.BaseContext memory) {
        StdConfig configDeployed = new StdConfig("./config.d.toml", false);
        StdConfig config = new StdConfig("./config.toml", false);

        return EngineLib.BaseContext({configDeployed: configDeployed, config: config, chainId: chainId, forkId: forkId});
    }

    /// @dev Create core for initial chain
    function createCore(
        Vm vm,
        uint chainId,
        uint fork,
        address validator
    ) internal returns (EngineLib.ChainConfig memory) {
        vm.selectFork(fork);

        EngineLib.BaseContext memory bc = getBaseContext(chainId, fork);
        address deployer = getDeployer(bc.configDeployed, chainId);

        vm.startPrank(deployer);
        EngineLib.ChainConfig memory core = DeployUsesCaseLib.deployCore(bc, validator);
        vm.stopPrank();

        _setupCore(vm, core);

        return core;
    }

    /// @dev Create core fot NOT-initial chain
    function createCore(
        Vm vm,
        uint chainId,
        uint fork,
        address validator,
        IHost.HostInitPayload memory init
    ) internal returns (EngineLib.ChainConfig memory) {
        vm.selectFork(fork);

        EngineLib.BaseContext memory bc = getBaseContext(chainId, fork);
        address deployer = getDeployer(bc.configDeployed, chainId);

        vm.startPrank(deployer);
        EngineLib.ChainConfig memory core = DeployUsesCaseLib.deployCore(bc, validator, init);
        vm.stopPrank();

        _setupCore(vm, core);

        return core;
    }

    function getContext(EngineLib.ChainConfig memory chain, address user) internal returns (EngineLib.Context memory) {
        return EngineLib.Context({core: chain, bc: getBaseContext(chain.chainId, chain.fork), user: user});
    }

    function getDeployer(StdConfig configDeployed, uint chainId) internal view returns (address) {
        IProxyFactory proxyFactory = IProxyFactory(configDeployed.get(chainId, "PROXY_FACTORY").toAddress());
        return IOwnable(address(proxyFactory)).owner();
    }

    function _setupCore(Vm vm, EngineLib.ChainConfig memory core) internal {
        vm.startPrank(core.multisig);
        HostSetupLib.setupHostSettings(core);
        HostSetupLib.setupHostChainSettings(core.chainId, core);
        HostSetupLib.setTokenImplementations(core);
        RestrictHostUtils.setupValidator(core.authority, address(core.host), core.hostValidator);
        vm.stopPrank();
    }
}
