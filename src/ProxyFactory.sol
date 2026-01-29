// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Proxy} from "./Proxy.sol";
import {IProxyFactory} from "./interfaces/IProxyFactory.sol";
import {IProxy} from "./interfaces/IProxy.sol";

/// @notice Factory contract to create clones of the Proxy contract with deterministic addresses
/// @dev Bytecode of Proxy is never changed.
/// @author omriss (https://github.com/omriss)
contract ProxyFactory is IProxyFactory, Ownable {
    /// @notice Address of the master Proxy contract to be cloned
    address public immutable MASTER_PROXY;

    /// @notice Whitelisted addresses allowed to create new proxies
    mapping(address => bool) public whitelisted;

    modifier onlyWhitelisted() {
        _onlyWhitelisted();
        _;
    }

    constructor() Ownable(msg.sender) {
        // Deploy proxy only once. All other proxy instances will be clones of this one.
        // Master proxy is never initialized - it serves only as a bytecode template.
        // Each clone has independent storage and is initialized separately via _initProxy.
        MASTER_PROXY = address(new Proxy());
    }

    /// @inheritdoc IProxyFactory
    function setWhitelisted(address addr, bool status) external onlyOwner {
        whitelisted[addr] = status;
        emit Whitelisted(addr, status);
    }

    /// @inheritdoc IProxyFactory
    function getProxyInitCode() external view returns (bytes memory) {
        /// @dev EIP-1167 minimal proxy bytecode format:
        /// 3d602d80600a3d3981f3363d3d373d3d3d363d73{implementation}5af43d82803e903d91602b57fd5bf3
        /// where {implementation} is the 20-byte address of MASTER_PROXY
        return abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73", MASTER_PROXY, hex"5af43d82803e903d91602b57fd5bf3"
        );
    }

    /// @inheritdoc IProxyFactory
    function predictAddress(bytes32 salt) external view returns (address) {
        return Clones.predictDeterministicAddress(MASTER_PROXY, salt, address(this));
    }

    /// @inheritdoc IProxyFactory
    function createNewProxy(address implementation, bytes memory data_) external payable returns (address proxy) {
        // there are no restrictions on who can call this function
        proxy = Clones.clone(address(MASTER_PROXY));
        _initProxy(proxy, implementation, data_);
    }

    /// @inheritdoc IProxyFactory
    function create2NewProxy(
        bytes32 salt,
        address implementation,
        bytes memory data_
    ) external payable onlyWhitelisted returns (address proxy) {
        proxy = Clones.cloneDeterministic(address(MASTER_PROXY), salt);
        _initProxy(proxy, implementation, data_);
    }

    function _initProxy(address proxy, address implementation, bytes memory data_) internal {
        IProxy(proxy).initProxy{value: msg.value}(implementation, data_);
        emit ProxyCreated(proxy);
    }

    function _onlyWhitelisted() internal view {
        require(whitelisted[msg.sender], NotWhitelisted());
    }
}
