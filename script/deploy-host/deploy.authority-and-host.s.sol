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

    // Ethereum
    bytes32 constant SALT_HOST_MAINNET = 0xece9ebd163ac88bd95711ee95b86f0f473593c23de779f85d0fa56d69acc4f64;
    address constant TARGET_HOST_MAINNET = 0xaAAAAaaaaa0E3D26D4733570F4e4584D7872dDE2;
    bytes32 constant SALT_HOST_BRIDGE_MAINNET = 0xbab80f3b6e6a67bf68f4f54b18b658e98fe20d9ad8f6d8ac2698c58320b4d3de;
    address constant TARGET_HOST_BRIDGE_MAINNET = 0xBbBbBbBBBBE003BD773877C193D4B97aDe002cca;
    bytes32 constant SALT_DATA_READER_MAINNET = 0x5c837a9ab7fc64bc2c65553a3ceafdc6ae3f78c1944602e8da989d9ec1fc28b3;
    address constant TARGET_DATA_READER_MAINNET = 0xddDDdDDDDd9cA61A2CA1D4997AAA79422AC7a3e9;

    // Sonic
    bytes32 constant SALT_HOST_SONIC = 0x4fc6b5a468ed22ab3db705a64a0460587f5b2762d84261420525d1cef7602453;
    address constant TARGET_HOST_SONIC = 0xaAaAAAAAAA4eE37D78fB985d5fde1aD7fE2e4678;
    bytes32 constant SALT_HOST_BRIDGE_SONIC = 0x2ea4c0df1f5488c3b1c6e67b1cb0b1d3e79b84e245400ae008d7f71080a975ea;
    address constant TARGET_HOST_BRIDGE_SONIC = 0xBbBbbbbBBb3B8D01c5Bcd4D7Ac23E12FAb8AbEBE;
    bytes32 constant SALT_DATA_READER_SONIC = 0x0f732550eaf8c6937183b31fcaadb149cd56877936795795ec2414db03ca2e81;
    address constant TARGET_DATA_READER_SONIC = 0xdDDDddDdDDd9526CCf8F8f000e9FeCcf0dA67465;

    // Plasma
    bytes32 constant SALT_HOST_PLASMA = 0x3bc30268b17f189af4aded81112d055ca79bc0c3ce8979937e7a124be054cd22;
    address constant TARGET_HOST_PLASMA = 0xAaaaaAaAaab938Ec720771F9d56D38443EcE00eD;
    bytes32 constant SALT_HOST_BRIDGE_PLASMA = 0xbc70ae657d509ea5ed1307c026eefc19bc6b3b8b8976e61ccbd44ccdea68df2f;
    address constant TARGET_HOST_BRIDGE_PLASMA = 0xBbbBBbbbbb11Bbe5c8682784e4A2e651A716a1c7;
    bytes32 constant SALT_DATA_READER_PLASMA = 0x4dc664561a5e6defd6277f4ba1e44fbaf2988192c8c120cf6f4ef2927f4dcca9;
    address constant TARGET_DATA_READER_PLASMA = 0xDDDdDDdDdD17376E74842dD397D61deA22ECFA35;

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
