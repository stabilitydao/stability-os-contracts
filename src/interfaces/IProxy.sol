// SPDX-License-Identifier: MIT
pragma solidity 0.8.28; // We need to fix version of compilator because changing of compilator will change getProxyInitCodeHash results

/// @dev Proxy of core contract implementation
/// @dev To upgrade proxy use UUPSUpgradeable functions - Proxy.upgradeToAndCall()
/// @dev Proxy will redirect the call to the implementation - UUPSUpgradeable.upgradeToAndCall()
interface IProxy {
    error ProxyAlreadyInitialized();
    error ImplementationIsNotContract();

    /// @notice Set first implementation address
    /// @dev Separate function is used instead of constructor here to be able to use CREATE2 addresses.
    /// CREATE2 address depends on constructor parameters (if any). It is not suitable for Host implementation.
    function initProxy(address implementation, bytes memory data_) external payable;

    /// @notice Return current logic implementation
    /// @return Address of implementation contract
    function implementation() external view returns (address);
}
