// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {Test} from "forge-std/Test.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {DeployIntentsLib} from "../commands/DeployIntentsLib.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";

/*
 * Deploy authority using predicted host address
 * Allow authority to create new proxies in ProxyFactory
 */
contract DeployUsesCasesTest is Test {
    uint constant internal ETHEREUM_FORK_BLOCK = 24481863; // Feb-18-2026 06:15:47 AM +UTC

    IProxyFactory public proxyFactory;
    bytes32 internal saltHost;
    bytes32 internal saltHostBridge;
    bytes32 internal saltHostReader;
    bytes32 internal saltHostCodec;
    address internal host;
    address internal hostBridge;
    address internal dataReader;
    address internal hostCodec;

    constructor() {
        vm.selectFork(vm.createFork(vm.envString("ETHEREUM_RPC_URL"), ETHEREUM_FORK_BLOCK));
        {
            StdConfig configDeployed = new StdConfig("./config.d.toml", false);
            proxyFactory = IProxyFactory(configDeployed.get("PROXY_FACTORY").toAddress());
        }

        {
            StdConfig config = new StdConfig("./config.toml", false);

            saltHost = config.get("SALT_HOST").toBytes32();
            saltHostBridge = config.get("SALT_HOST_BRIDGE").toBytes32();
            saltHostReader = config.get("SALT_DATA_READER").toBytes32();
            saltHostCodec = config.get("SALT_HOST_CODEC").toBytes32();

            host = config.get("HOST").toAddress();
            hostBridge = config.get("HOST_BRIDGE").toAddress();
            dataReader = config.get("DATA_READER").toAddress();
            hostCodec = config.get("HOST_CODEC").toAddress();
        }
    }

    function testDeployAuthority() public {

        /// @dev 1. Owner of proxy factory should be able to deploy authority and set it up correctly
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();

        // @dev 2. Build intent from config
        DeployIntentsLib.IntentDeployAuthorityIn memory intent = DeployIntentsLib.buildIntentDeployAuthority(address(proxyFactory), proxyFactoryOwner);

        // @dev 3. Proxy factory owner deploys authority and sets up permissions for it
        IAuthority authority = IAuthority(DeployIntentsLib.deployAuthority(vm, intent));

        // ---------------------------------- Check results
        (bool isMember, uint32 executionDelay) = authority.hasRole(0, proxyFactoryOwner);
        assertTrue(isMember, "Initial admin is correct");
        assertEq(executionDelay, 0, "no delay");

        assertEq(authority.HOST(), proxyFactory.predictAddress(saltHost), "Host is correct");
        assertEq(authority.PROXY_FACTORY(), address(proxyFactory), "Proxy factory is correct");
    }

    function testDeployHost() public {
        /// @dev 1. Prepare init params for Host
        IHost.HostInitPayload memory init = IHost.HostInitPayload({
            usedSymbols: new string[](0),
            daoHostSymbol: "",
            daoHostUid: 0,
            hostVersion: "2026.00.00"
        });

        /// @dev 2. Owner of proxy factory should be able to deploy authority and Host and set it up correctly
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();


        /// @dev Assume here that Authority is not deployed yet
        address authority = DeployIntentsLib.deployAuthority(
            vm,
            DeployIntentsLib.buildIntentDeployAuthority(address(proxyFactory), proxyFactoryOwner)
        );


        /// @dev 2. Build intent from config
        DeployIntentsLib.IntentDeployHostIn memory intent = DeployIntentsLib.buildIntentDeployHost(authority, proxyFactoryOwner, init);

        /// @dev 3. Deploy host
        address deployedHost = DeployIntentsLib.deployHost(vm, intent);

        /// ---------------------------------- Check results
        assertNotEq(deployedHost, address(0), "Host deployed");
    }

    function testDeployHostBridge() public {

    }

    function testDeployHostCodec() public {

    }

    function testDeployDataReader() public {

    }

    function testDeployAll() public {

    }

}