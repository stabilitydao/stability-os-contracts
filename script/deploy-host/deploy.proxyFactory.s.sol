// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {StdConfig} from "forge-std/StdConfig.sol";
import {Variable, LibVariable} from "forge-std/LibVariable.sol";
import {Script} from "forge-std/Script.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";

/// @notice Deploy ProxyFactory
contract DeployProxyFactory is Script {
    using LibVariable for Variable;

    function run() external {
        // ---------------------- Read initial data
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // ---------------------- Initialize
        StdConfig configDeployed = new StdConfig("./config.d.toml", true); // auto-write deployed addresses

        require(
            uint(configDeployed.get("PROXY_FACTORY").ty.kind) == 0, "ProxyFactory is already deployed on this chain"
        );

        // ---------------------- Deploy
        vm.startBroadcast(deployerPrivateKey);

        // create proxy factory
        ProxyFactory proxyFactory = new ProxyFactory();

        // allow the owner to create proxies
        proxyFactory.setWhitelisted(proxyFactory.owner(), true);

        // ---------------------- Write results
        vm.stopBroadcast();
        configDeployed.set("PROXY_FACTORY", address(proxyFactory));
    }
}
