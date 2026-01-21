// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Factory contract to deploy Proxy contracts using CREATE2
/// @dev Bytecode of Proxy is never changed.
/// @author omriss (https://github.com/omriss)
interface IProxyFactory {
    /// @notice Get keccak256 hash of Proxy creationCode for CREATE2
    function getProxyInitCodeHash() external view returns (bytes32);

    /// @notice Get address of Proxy deployed using CREATE2 with given salt and implementation
    /// @param salt Salt to get CREATE2 deployment address
    /// @param initCodeHash keccak256 hash of the init code of the contract to be deployed. Normally it's getProxyInitCodeHash()
    /// @param thisAddress Address of proxy deployer contract. Normally this is address of this factory.
    /// @return Future deployment address
    function getCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash,
        address thisAddress
    ) external pure returns (address);

    /// @notice Deploy new Proxy without logic initialization using CREATE2
    /// @custom:restriction Whitelisted addresses only
    /// @dev This function must be called by other factory contracts that additionally initialize the proxy after deployment
    /// @param salt Salt to get CREATE2 deployment address
    /// @return proxy Address of deployed Proxy contract
    function create2NewProxy(bytes32 salt) external returns (address proxy);

    /// @notice Deploy new Proxy without logic initialization using CREATE
    /// @custom:restriction No restrictions
    /// @dev This function must be called by other factory contracts that additionally initialize the proxy after deployment
    /// @return proxy Address of deployed Proxy contract
    function createNewProxy() external returns (address proxy);
}