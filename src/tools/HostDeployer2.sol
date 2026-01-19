// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IProxy} from "../interfaces/IProxy.sol";
import {Proxy} from "../base/Proxy.sol";
import {HostAccessManager} from "../HostAccessManager.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IHostAccessManager} from "../interfaces/IHostAccessManager.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IHostProxyFactory} from "../interfaces/IHostProxyFactory.sol";

/// @notice Auxiliary contract to deploy HostAccessManager, HostProxyFactory and Host in proper order
contract HostDeployer2 {
    address public immutable DEPLOYER;

    /// @notice Address of deployed ERC1967Proxy
    address public immutable PROXY_IMPLEMENTATION;

    error NotDeployer();
    event DeployHost(address authorityInitialAdmin, address accessManager, address hostProxyFactory, address host);

    constructor(address proxyImplementation) {
        PROXY_IMPLEMENTATION = proxyImplementation;
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

        address hostFactoryPredicted = Clones.predictDeterministicAddress(
            PROXY_IMPLEMENTATION,
            hostProxyFactorySalt,
            address(this) // deployer
        );
        address hostPredicted = Clones.predictDeterministicAddress(
            PROXY_IMPLEMENTATION,
            hostSalt,
            hostFactoryPredicted
        );

        accessManager = address(new HostAccessManager(authorityInitialAdmin, hostPredicted));

        hostProxyFactory = _createNewProxy(hostProxyFactorySalt, hostProxyFactoryImplementation);
        IHosted(hostProxyFactory).initialize(accessManager, "");

        host = IHostProxyFactory(hostProxyFactory).deployProxy(hostSalt, hostImplementation, hostPayload);
        require(IHostAccessManager(accessManager).HOST() == host, "HostDeployer: invalid host in access manager");

        emit DeployHost(authorityInitialAdmin, accessManager, hostProxyFactory, host);
    }

    function _createNewProxy(bytes32 salt, address implementation) internal returns (address proxy) {
        proxy = salt == 0
            ? address(new ERC1967Proxy(implementation, ""))  // create   // todo if create is not allowed we must require salt != 0
            : address(new ERC1967Proxy{salt: salt}(implementation, "")); // create2
    }
}
