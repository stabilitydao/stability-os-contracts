// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC1967ProxyFactory} from "../interfaces/IERC1967ProxyFactory.sol";

/// @notice Minimal immutable factory contract to deploy ERC1967Proxy contracts using CREATE/CREATE2
/// @dev Bytecode of ERC1967Proxy is never changed.
/// @dev No events, no restrictions.
/// @author omriss (https://github.com/omriss)
contract ERC1967ProxyFactory is IERC1967ProxyFactory {

    /// @inheritdoc IERC1967ProxyFactory
    function getProxyInitCodeHash(address implementation, bytes memory data) external pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(implementation, data)
            )
        );
    }

    /// @inheritdoc IERC1967ProxyFactory
    function getCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash,
        address thisAddress
    ) external pure returns (address) {
        return address(uint160(uint(keccak256(abi.encodePacked(bytes1(0xff), thisAddress, salt, initCodeHash)))));
    }

    /// @inheritdoc IERC1967ProxyFactory
    function createNewProxy(address implementation, bytes memory _data) external returns (address proxy) {
        proxy = address(new ERC1967Proxy(implementation, _data));
    }

    /// @inheritdoc IERC1967ProxyFactory
    function create2NewProxy(bytes32 salt, address implementation, bytes memory _data) external returns (address proxy) {
        proxy = address(new ERC1967Proxy{salt: salt}(implementation, _data)); // create2
    }
}