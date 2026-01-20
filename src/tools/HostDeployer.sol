// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {HostAccessManager} from "../HostAccessManager.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IHostAccessManager} from "../interfaces/IHostAccessManager.sol";
import {IERC1967ProxyFactory} from "../interfaces/IERC1967ProxyFactory.sol";

/// @notice Auxiliary contract to deploy HostAccessManager, HostProxyFactory and Host in proper order.
/// @dev The main goal is to create and initialize HostProxyFactory inside single tx.
/// @dev All other contracts should be deployed using HostProxyFactory.
/// @author omriss (https://github.com/omriss)
contract HostDeployer {
    address public immutable DEPLOYER;

    /// @notice Address of deployed ERC1967ProxyFactory
    IERC1967ProxyFactory public immutable ERC1967_PROXY_FACTORY;

    error NotDeployer();
    error UnexpectedHostAddress();
    event DeployHost(address authorityInitialAdmin, address accessManager, address hostProxyFactory, address host);

    /// @param erc1967ProxyFactory_ Address of deployed ERC1967ProxyFactory. This factory is used to deploy all proxies.
    constructor(address erc1967ProxyFactory_) {
        ERC1967_PROXY_FACTORY = IERC1967ProxyFactory(erc1967ProxyFactory_);
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

        address hostPredicted = ERC1967_PROXY_FACTORY.getCreate2Address(
            hostSalt,
            ERC1967_PROXY_FACTORY.getProxyInitCodeHash(hostImplementation, ""),
            address(ERC1967_PROXY_FACTORY)
        );
        address hostFactoryPredicted = ERC1967_PROXY_FACTORY.getCreate2Address(
            hostProxyFactorySalt,
            ERC1967_PROXY_FACTORY.getProxyInitCodeHash(hostProxyFactory, ""),
            address(ERC1967_PROXY_FACTORY)
        );
        console.log("hostPredicted", hostPredicted);
        console.log("hostFactoryPredicted", hostFactoryPredicted);

        accessManager = address(new HostAccessManager(authorityInitialAdmin, hostPredicted));

        // we can use abi.encodeCall(IHosted.initialize, (accessManager, ""))
        // but HostDeployer is more convenient than pure deploy script
        hostProxyFactory = ERC1967_PROXY_FACTORY.create2NewProxy(hostProxyFactorySalt, hostProxyFactoryImplementation, "");
        IHosted(hostProxyFactory).initialize(accessManager, "");

        // authority is not configured yet so we cannot deploy Host through HostProxyFactory
        //host = IHostProxyFactory(hostProxyFactory).deployProxy(hostSalt, hostImplementation, hostPayload);
        host = ERC1967_PROXY_FACTORY.create2NewProxy(hostSalt, hostImplementation, "");
        IHosted(host).initialize(accessManager, hostPayload);

        console.log("host", host);
        console.log("hostProxyFactory", hostProxyFactory);

        require(IHostAccessManager(accessManager).HOST() == host, UnexpectedHostAddress());

        emit DeployHost(authorityInitialAdmin, accessManager, hostProxyFactory, host);
    }
}
