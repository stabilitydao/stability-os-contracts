// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {StdConfig} from "forge-std/StdConfig.sol";
import {Variable, LibVariable} from "forge-std/LibVariable.sol";
import {Script} from "forge-std/Script.sol";
import {Authority} from "../../src/Authority.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";

/// @notice Deploy ProxyFactory
contract DeployProxyFactory is Script {
    using LibVariable for Variable;

    function run() external {
        // ---------------------- Read initial data
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address multisig = vm.envAddress("MULTISIG");
        require(multisig != address(0), "Multisig is not set");

        address hostPredicted = vm.envAddress("HOST_PREDICTED");

        // ---------------------- Initialize
        StdConfig configDeployed = new StdConfig("./config.d.toml", true); // auto-write deployed addresses

        require(uint(configDeployed.get("PROXY_FACTORY").ty.kind) != 0, "ProxyFactory is NOT deployed on this chain");
        address proxyFactory = configDeployed.get("PROXY_FACTORY").toAddress();

        require(uint(configDeployed.get("AUTHORITY").ty.kind) == 0, "Authority is deployed on this chain");

        // ---------------------- Deploy
        vm.startBroadcast(deployerPrivateKey);

        Authority authority = new Authority(multisig, hostPredicted, address(proxyFactory));

        // allow authority to create new proxies
        IProxyFactory(proxyFactory).setWhitelisted(address(authority), true);

        // allow host to create new proxies
        IProxyFactory(proxyFactory).setWhitelisted(address(hostPredicted), true);

        // ---------------------- Write results
        vm.stopBroadcast();
        configDeployed.set("AUTHORITY", address(authority));
    }
}
