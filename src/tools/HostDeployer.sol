// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {HostAccessManager} from "../HostAccessManager.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IHostAccessManager} from "../interfaces/IHostAccessManager.sol";
import {IProxyFactory} from "../interfaces/IProxyFactory.sol";
import {IProxy} from "../interfaces/IProxy.sol";

/// @notice Auxiliary contract to deploy HostAccessManager, HostProxyFactory and Host in proper order.
/// @dev The main goal is to create and initialize HostProxyFactory inside single tx.
/// @dev All other contracts should be deployed using HostProxyFactory.
/// @author omriss (https://github.com/omriss)
contract HostDeployer {
    address public immutable DEPLOYER;

    /// @notice Address of deployed ProxyFactoryCreate.sol.sol
    IProxyFactory public immutable PROXY_FACTORY;

    error NotDeployer();
    error UnexpectedHostAddress();
    event DeployHost(address authorityInitialAdmin, address accessManager, address hostProxyFactory, address host);

    /// @param erc1967ProxyFactory_ Address of deployed ProxyFactoryCreate.sol.sol. This factory is used to deploy all proxies.
    constructor(address erc1967ProxyFactory_) {
        PROXY_FACTORY = IProxyFactory(erc1967ProxyFactory_);
        DEPLOYER = msg.sender;
    }

    /// @notice Deploy HostAccessManager (immutable) and two proxy contracts: HostProxyFactory and Host
    /// @param hostProxyFactorySalt Salt for HostProxyFactory CREATE2 deployment
    /// @param hostSalt Salt for Host CREATE2 deployment
    /// @param authorityInitialAdmin Admin address to initialize HostAccessManager
    /// @param hostPayload Initialization payload for Host contract
    /// @return accessManager Deployed HostAccessManager address
    /// @return hostProxyFactory Deployed HostProxyFactory address
    /// @return host Deployed Host address
    function deploy(
        bytes32 hostProxyFactorySalt,
        bytes32 hostSalt,
        address authorityInitialAdmin,
        bytes memory hostPayload,
        address hostProxyFactoryImplementation,
        address hostImplementation
    ) external returns (address accessManager, address hostProxyFactory, address host) {
        require(msg.sender == DEPLOYER, NotDeployer());

        address hostPredicted = PROXY_FACTORY.getCreate2Address(
            hostSalt,
            PROXY_FACTORY.getProxyInitCodeHash(),
            address(PROXY_FACTORY)
        );
        address hostFactoryPredicted = PROXY_FACTORY.getCreate2Address(
            hostProxyFactorySalt,
            PROXY_FACTORY.getProxyInitCodeHash(),
            address(PROXY_FACTORY)
        );
        console.log("hostPredicted", hostPredicted);
        console.log("hostFactoryPredicted", hostFactoryPredicted);

        accessManager = address(new HostAccessManager(authorityInitialAdmin, hostPredicted)); // todo

        // we can use abi.encodeCall(IHosted.initialize, (accessManager, ""))
        // but HostDeployer is more convenient than pure deploy script
        hostProxyFactory = PROXY_FACTORY.create2NewProxy(hostProxyFactorySalt);
        IProxy(hostProxyFactory).initProxy(hostProxyFactoryImplementation);
        IHosted(hostProxyFactory).initialize(accessManager, "");

        // authority is not configured yet so we cannot deploy Host through HostProxyFactory
        //host = IHostProxyFactory(hostProxyFactory).deployProxy(hostSalt, hostImplementation, hostPayload);
        host = PROXY_FACTORY.create2NewProxy(hostSalt);
        IProxy(host).initProxy(hostImplementation);
        IHosted(host).initialize(accessManager, hostPayload);

        console.log("host", host);
        console.log("hostProxyFactory", hostProxyFactory);

        require(IHostAccessManager(accessManager).HOST() == host, UnexpectedHostAddress());

        emit DeployHost(authorityInitialAdmin, accessManager, hostProxyFactory, host);
    }
}
