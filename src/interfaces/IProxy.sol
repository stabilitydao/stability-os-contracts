// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @dev A proxy for all contracts implemented on the Host platform.
/// @dev To upgrade proxy use UUPSUpgradeable functions - Proxy.upgradeToAndCall()
/// @dev Proxy will redirect the call to the implementation - UUPSUpgradeable.upgradeToAndCall()
interface IProxy {
    error ProxyAlreadyInitialized();

    /// @notice Initializes the upgradeable proxy with an initial implementation specified by `implementation_`.
    /// @param implementation_ Address of the initial implementation.
    /// @param data_ If `_data` is nonempty, it's used as data in a delegate call to `implementation_`.
    /// This will typically be an encoded function call
    /// i.e. abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(init data)))
    ///
    /// Requirements:
    /// - If `data` is empty, `msg.value` must be zero.
    function initProxy(address implementation_, bytes memory data_) external payable;

    /// @notice Return current logic implementation
    /// @return Address of implementation contract
    function implementation() external view returns (address);
}
