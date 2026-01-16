// SPDX-License-Identifier: MIT
pragma solidity 0.8.28; // We need to fix version of compilator because changing of compilator will change getProxyInitCodeHash results

import {UpgradeableProxy} from "../base/UpgradeableProxy.sol";
import {IProxy} from "../interfaces/IProxy.sol";

/// @title Proxy for Host-platform contracts.
/// @dev ERC-1967: Proxy Storage Slots used.
/// @dev The proxy is used together with Hosted-based implementation.
/// @dev To upgrade proxy use UUPSUpgradeable functions - Proxy.upgradeToAndCall()
/// @dev Proxy will redirect the call to the UUPSUpgradeable.upgradeToAndCall()
contract Proxy is UpgradeableProxy, IProxy {
    /// @inheritdoc IProxy
    function initProxy(address logic) external override {
        _init(logic);
    }

    /// @inheritdoc IProxy
    function implementation() external view override returns (address) {
        return _implementation();
    }
}
