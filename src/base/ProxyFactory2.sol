// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IProxyFactory} from "../interfaces/IProxyFactory.sol";
import {Proxy} from "../base/Proxy.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "../../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/// @notice Minimal immutable factory contract to deploy ERC1967Proxy contracts using CREATE/CREATE2
/// @dev Bytecode of ERC1967Proxy is never changed.
/// @dev No events, no restrictions.
/// @author omriss (https://github.com/omriss)
contract ProxyFactory2 is IProxyFactory, AccessControl { // todo AccessControl, todo restrictions

    address public immutable MASTER_PROXY;
    bytes32 public immutable MASTER_PROXY_CLONE_CODE_HASH;

    constructor() { // Ownable(msg.sender)
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        MASTER_PROXY = address(new Proxy());
        MASTER_PROXY_CLONE_CODE_HASH = keccak256(_getCloneBytecode(MASTER_PROXY));
    }

    /// @inheritdoc IProxyFactory
    function getProxyInitCodeHash() external view returns (bytes32) {
//        bytes memory cloneCode = _getCloneBytecode(MASTER_PROXY);
//        return keccak256(cloneCode);
        return MASTER_PROXY_CLONE_CODE_HASH;
    }

    /// @inheritdoc IProxyFactory
    function getCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash,
        address thisAddress
    ) external pure returns (address) {
        return address(uint160(uint(keccak256(
            abi.encodePacked(bytes1(0xff), thisAddress, salt, initCodeHash)
        ))));
    }

    // todo
    function predictDeterministicAddress(bytes32 salt) external view returns (address) {
        return Clones.predictDeterministicAddress(MASTER_PROXY, salt, address(this));
    }

    /// @inheritdoc IProxyFactory
    function createNewProxy() external returns (address proxy) {
        proxy = Clones.clone(address(MASTER_PROXY));
    }

    /// @inheritdoc IProxyFactory
    function create2NewProxy(bytes32 salt) external returns (address proxy) {
        proxy = Clones.cloneDeterministic(address(MASTER_PROXY), salt);
    }

    function _getCloneBytecode(address implementation) internal pure returns (bytes memory) {
        // EIP-1167 minimal proxy bytecode
        // 3d602d80600a3d3981f3363d3d373d3d3d363d73bebebebebebebebebebebebebebebebebebebebe5af43d82803e903d91602b57fd5bf3
        // bebebebe... is replaced by {implementation}

        bytes20 implementationBytes = bytes20(implementation);

        return abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            implementationBytes,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
    }
}