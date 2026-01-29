// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Factory contract to deploy Proxy contracts using CREATE2
/// @dev Bytecode of Proxy is never changed.
/// @author omriss (https://github.com/omriss)
interface IProxyFactory {
    event Whitelisted(address indexed addr, bool status);
    event ProxyCreated(address indexed proxy);

    error NotWhitelisted();

    /// @notice Set the whitelisted {status} of an {addr}
    function setWhitelisted(address addr, bool status) external;

    /// @notice Deploy new Proxy without logic initialization using CREATE2
    /// @custom:restriction Whitelisted addresses only
    /// @dev This function must be called by other factory contracts that additionally initialize the proxy after deployment
    /// @param salt Salt to get CREATE2 deployment address
    /// @param implementation Address of implementation contract
    /// @param data_ If `_data` is nonempty, it's used as data in a delegate call to `implementation`.
    /// This will typically be an encoded function call.
    /// @return proxy Address of deployed Proxy contract
    function create2NewProxy(
        bytes32 salt,
        address implementation,
        bytes memory data_
    ) external payable returns (address proxy);

    /// @notice Deploy new Proxy without logic initialization using CREATE
    /// @custom:restriction No restrictions
    /// @dev This function must be called by other factory contracts that additionally initialize the proxy after deployment
    /// @param implementation Address of implementation contract
    /// @param data_ If `_data` is nonempty, it's used as data in a delegate call to `implementation`.
    /// This will typically be an encoded function call.
    /// @return proxy Address of deployed Proxy contract
    function createNewProxy(address implementation, bytes memory data_) external payable returns (address proxy);

    /// @notice Check if the addr is allowed to create new proxies
    function whitelisted(address addr) external view returns (bool);

    /// @notice Get master proxy init code for CREATE2
    function getProxyInitCode() external view returns (bytes memory);

    /// @notice Get address of Proxy deployed using CREATE2 with given salt
    /// @param salt Salt to get CREATE2 deployment address
    /// @return Future deployment address
    function predictAddress(bytes32 salt) external view returns (address);
}
