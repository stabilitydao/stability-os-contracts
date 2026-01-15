// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28; // todo We need to fix version of compilator because changing of compilator will change getProxyInitCodeHash results

import {UpgradeableProxy} from "../base/UpgradeableProxy.sol";
import {IControllable} from "../interfaces/IControllable.sol"; // todo replace by IControllable2
import {IProxy} from "../interfaces/IProxy.sol";

/// @title Proxy for Stability Platform core contracts.
/// @dev ERC-1967: Proxy Storage Slots used.
/// @author JodsMigel (https://github.com/JodsMigel)
contract Proxy is UpgradeableProxy, IProxy {
    /// @inheritdoc IProxy
    function initProxy(address logic) external override {
        _init(logic);
    }

    /// @inheritdoc IProxy
    function upgrade(address newImplementation) external override {
        // todo use IControllable2
        require(IControllable(address(this)).platform() == msg.sender, IControllable.NotPlatform());
        _upgradeTo(newImplementation);
        // the new contract must have the same ABI and you must have the power to change it again
        require(IControllable(address(this)).platform() == msg.sender, IControllable.NotPlatform());
    }

    /// @inheritdoc IProxy
    function implementation() external view override returns (address) {
        return _implementation();
    }
}
