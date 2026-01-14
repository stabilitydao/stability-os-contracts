// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @notice Factory interface for deploying proxy contracts based in IControllable2
interface IHostProxyFactory {
    event NewSeedToken(address seedToken, bytes payload);
    event NewTgeToken(address tgeToken, bytes payload);
    event NewContractDeployed(address proxy, address implementation, bytes payload);

    event NewSeedTokenImplementation(address implementation);
    event NewTgeTokenImplementation(address implementation);

    /// @custom:storage-location erc7201:stability-os-contracts.HostProxyFactory
    struct HostProxyFactoryStorage {
        /// @notice Current implementation of SeedToken logic contract
        address seedTokenImplementation;

        /// @notice All deployed seed tokens
        EnumerableSet.AddressSet seedTokens;

        /// @notice Current implementation of TgeToken logic contract
        address tgeTokenImplementation;

        /// @notice All deployed tge tokens
        EnumerableSet.AddressSet tgeTokens;
    }

    /// @notice Get CREATE2 address
    /// @param salt Provided salt for CREATE2
    /// @param initCodeHash Hash of contract creationCode
    /// @param thisAddress Address of this factory
    /// @return Future deployment address
    function getCreate2Address(bytes32 salt, bytes32 initCodeHash, address thisAddress) external pure returns (address);

    /// @notice Get keccak256 hash of Proxy creationCode for CREATE2
    function getProxyInitCodeHash() external view returns (bytes32);

    //region -------------------- View deployed addresses

    /// @notice Deployed seed tokens
    function seedTokens() external view returns (address[] memory);

    /// @notice Deployed tge tokens
    function tgeTokens() external view returns (address[] memory);

    //endregion -------------------- View deployed addresses

    //region -------------------- View implementations

    /// @notice Get SeedToken logic contract implementation
    function seedTokenImplementation() external view returns (address);

    /// @notice Get TgeToken logic contract implementation
    function tgeTokenImplementation() external view returns (address);

    //endregion -------------------- View implementations

    //region -------------------- Set implementations

    /// @notice Set SeedToken logic contract implementation
    /// @custom:require Multisig
    /// @param implementation Address of new logic contract
    function setSeedTokenImplementation(address implementation) external;

    /// @notice Set TgeToken logic contract implementation
    /// @custom:require Multisig
    /// @param implementation Address of new logic contract
    function setTgeTokenImplementation(address implementation) external;

    //endregion -------------------- Set implementations

    //region -------------------- Deploy

    /// @notice Deploy new proxy contract
    /// @param salt Salt for create2 deployment
    /// @param logic Address of logic contract
    /// @param payload Initialization payload to pass to IControllable2.initialize.
    /// Payload is created using abi.encode() and decoded using abi.decode(). Set of params depend on logic contract.
    /// @return Address of deployed proxy contract
    function deployProxy(bytes32 salt, address logic, bytes memory payload) external returns (address);

    /// @notice Deploy new SeedToken proxy contract
    /// @custom:require Host
    /// @param salt Salt for create2 deployment
    /// @param payload Initialization payload to pass to IControllable2.initialize.
    /// Payload is created using abi.encode() and decoded using abi.decode(). Set of params depend on logic contract.
    /// @return Address of deployed proxy contract
    function deploySeedToken(bytes32 salt, bytes memory payload) external returns (address);

    /// @notice Deploy new TgeToken proxy contract
    /// @custom:require Host
    /// @param salt Salt for create2 deployment
    /// @param payload Initialization payload to pass to IControllable2.initialize.
    /// Payload is created using abi.encode() and decoded using abi.decode(). Set of params depend on logic contract.
    /// @return Address of deployed proxy contract
    function deployTgeToken(bytes32 salt, bytes memory payload) external returns (address);

    //endregion -------------------- Deploy
}
