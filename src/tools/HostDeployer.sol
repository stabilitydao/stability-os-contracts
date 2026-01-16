// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IProxy} from "../interfaces/IProxy.sol";
import {Proxy} from "../base/Proxy.sol";
import {HostAccessManager} from "../HostAccessManager.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IHostAccessManager} from "../interfaces/IHostAccessManager.sol";
import {HostProxyFactory} from "../HostProxyFactory.sol";
import {Host} from "../Host.sol";

/// @notice Auxiliary contract to deploy HostAccessManager, HostProxyFactory and Host in proper order
contract HostDeployer {
    address public immutable DEPLOYER;

    constructor() {
        DEPLOYER = msg.sender;
    }

    /// @notice Get keccak256 hash of Proxy creationCode for CREATE2
    function getProxyInitCodeHash() external pure returns (bytes32) {
        return keccak256(type(Proxy).creationCode);
    }

    function getCreate2Address(bytes32 salt, bytes32 initCodeHash, address thisAddress) public pure returns (address) {
        return address(uint160(uint(keccak256(abi.encodePacked(bytes1(0xff), thisAddress, salt, initCodeHash)))));
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
        bytes memory hostPayload
    ) external returns (address accessManager, address hostProxyFactory, address host) {
        require(msg.sender == DEPLOYER, "HostDeployer: only deployer");

        address hostPredicted = getCreate2Address(hostSalt, this.getProxyInitCodeHash(), address(this));

        accessManager = address(new HostAccessManager(authorityInitialAdmin, hostPredicted));

        hostProxyFactory = _createNewProxy(hostProxyFactorySalt);
        IProxy(hostProxyFactory).initProxy(address(new HostProxyFactory()));
        IHosted(hostProxyFactory).initialize(accessManager, "");

        host = _createNewProxy(hostSalt);
        IProxy(host).initProxy(address(new Host()));
        IHosted(host).initialize(accessManager, hostPayload);

        require(IHostAccessManager(accessManager).HOST() == host, "HostDeployer: invalid host in access manager");
    }

    function _createNewProxy(bytes32 salt) internal returns (address proxy) {
        proxy = salt == 0
            ? address(new Proxy())  // create   // todo if create is not allowed we must require salt != 0
            : address(new Proxy{salt: salt}()); // create2
    }
}
