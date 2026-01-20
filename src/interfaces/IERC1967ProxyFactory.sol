// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Factory contract to deploy ERC1967Proxy contracts using CREATE2
/// @dev Bytecode of ERC1967Proxy is never changed.
/// @author omriss (https://github.com/omriss)
interface IERC1967ProxyFactory {
    /// @notice Get keccak256 hash of Proxy creationCode for CREATE2
    /// @param implementation Address of initial implementation contract - it will be passed to constructor of ERC1967Proxy
    /// @param data Data for proxy initialization ("" if proxy initialization will be called separately)
    function getProxyInitCodeHash(address implementation, bytes memory data) external view returns (bytes32);

    /// @notice Get address of ERC1967Proxy deployed using CREATE2 with given salt and implementation
    /// @param salt Salt to get CREATE2 deployment address
    /// @param initCodeHash keccak256 hash of the init code of the contract to be deployed. Normally it's getProxyInitCodeHash()
    /// @param thisAddress Address of proxy deployer contract. Normally this is address of this factory.
    /// @return Future deployment address
    function getCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash,
        address thisAddress
    ) external pure returns (address);

    /// @notice Deploy new ERC1967Proxy without logic initialization using CREATE2
    /// @dev This function must be called by other factory contracts that additionally initialize the proxy after deployment
    /// @param salt Salt to get CREATE2 deployment address
    /// @param implementation Address of the implementation contract
    /// @param data_ Data for proxy initialization ("" if proxy initialization will be called separately)
    /// @return proxy Address of deployed ERC1967Proxy contract
    function create2NewProxy(bytes32 salt, address implementation, bytes memory data_) external returns (address proxy);

    /// @notice Deploy new ERC1967Proxy without logic initialization using CREATE
    /// @dev This function must be called by other factory contracts that additionally initialize the proxy after deployment
    /// @param implementation Address of the implementation contract
    /// @param data_ Data for proxy initialization ("" if proxy initialization will be called separately)
    /// @return proxy Address of deployed ERC1967Proxy contract
    function createNewProxy(address implementation, bytes memory data_) external returns (address proxy);
}