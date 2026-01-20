// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IProxyFactory} from "../interfaces/IProxyFactory.sol";
import {Proxy} from "../base/Proxy.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "../../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/// @notice Minimal immutable factory contract to deploy ERC1967Proxy contracts using CREATE/CREATE2
/// @dev Bytecode of ERC1967Proxy is never changed.
/// @author omriss (https://github.com/omriss)
contract ProxyFactory is IProxyFactory, AccessControl { // todo AccessControl, todo restrictions

    constructor() { // Ownable(msg.sender)
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @inheritdoc IProxyFactory
    function getProxyInitCodeHash() external pure returns (bytes32) {
        return keccak256(abi.encodePacked(type(Proxy).creationCode));
    }

    /// @inheritdoc IProxyFactory
    function getCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash,
        address thisAddress
    ) external pure returns (address) {
        return address(uint160(uint(keccak256(abi.encodePacked(bytes1(0xff), thisAddress, salt, initCodeHash)))));
    }

    /// @inheritdoc IProxyFactory
    function createNewProxy() external returns (address proxy) {
        proxy = address(new Proxy());
    }

    /// @inheritdoc IProxyFactory
    function create2NewProxy(bytes32 salt) external returns (address proxy) {
        proxy = address(new Proxy{salt: salt}());
    }
}