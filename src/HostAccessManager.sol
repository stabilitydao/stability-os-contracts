// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IProxyFactory} from "./interfaces/IProxyFactory.sol";
import {IProxy} from "./interfaces/IProxy.sol";
import {IHosted} from "./interfaces/IHosted.sol";
import {IHostAccessManager} from "./interfaces/IHostAccessManager.sol";

// todo rename to Authority
contract HostAccessManager is AccessManager, IHostAccessManager {
    /// @inheritdoc IHostAccessManager
    address public immutable HOST;

    /// @inheritdoc IHostAccessManager
    address public immutable PROXY_FACTORY;

    event HostDeployed(address host);
    error UnexpectedHostAddress();

    constructor(address initialAdmin, address host_, address proxyFactory_) AccessManager(initialAdmin) {
        HOST = host_;
        PROXY_FACTORY = proxyFactory_;
    }

    // todo replace by multicall
    /// @notice Deploy Host contract proxy and initialize it in the single tx
    /// @dev This function is located inside HostAccessManager to reduce total number of deployed contracts
    /// @param salt_ Salt used to deploy the Host proxy contract. The given salt should produce HOST result address
    /// @param logic_ Address of Host implementation contract
    /// @return host Address of deployed Host proxy contract
    function deployHost(bytes32 salt_, address logic_, bytes memory hostPayload) external onlyAuthorized returns (address host) {
        host = IProxyFactory(PROXY_FACTORY).create2NewProxy(salt_);
        require(HOST == address(host), UnexpectedHostAddress());

        IProxy(host).initProxy(logic_);
        IHosted(host).initialize(address(this), hostPayload);

        emit HostDeployed(host);
    }
}
