// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IProxyFactory} from "../interfaces/IProxyFactory.sol";
import {IProxy} from "../interfaces/IProxy.sol";
import {Proxy} from "../base/Proxy.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Factory contract to create clones of the Proxy contract
/// @dev Bytecode of Proxy is never changed.
/// @author omriss (https://github.com/omriss)
contract ProxyFactory is IProxyFactory, Ownable {
    /// @notice Address of the master Proxy contract to be cloned
    address public immutable MASTER_PROXY;

    /// @notice Keccak256 hash of the init code of the clone of the master Proxy contract
    bytes32 internal immutable MASTER_PROXY_CLONE_CODE_HASH;

    /// @notice Whitelisted addresses allowed to create new proxies
    mapping(address => bool) public whitelisted;

    event Whitelisted(address indexed addr, bool status);
    error NotWhitelisted();

    event ProxyCreated(address indexed proxy);

    modifier onlyWhitelisted() {
        _onlyWhitelisted();
        _;
    }

    constructor() Ownable(msg.sender) {
        // Deploy proxy only once. All other proxy instances will be clones of this one.
        MASTER_PROXY = address(new Proxy());

        /// EIP-1167 minimal proxy bytecode
        /// 3d602d80600a3d3981f3363d3d373d3d3d363d73bebebebebebebebebebebebebebebebebebebebe5af43d82803e903d91602b57fd5bf3
        /// bebebebe... is replaced by {implementation}
        MASTER_PROXY_CLONE_CODE_HASH = keccak256(
            abi.encodePacked(
                hex"3d602d80600a3d3981f3363d3d373d3d3d363d73", MASTER_PROXY, hex"5af43d82803e903d91602b57fd5bf3"
            )
        );
    }

    /// @inheritdoc IProxyFactory
    function setWhitelisted(address addr, bool status) external onlyOwner {
        whitelisted[addr] = status;
        emit Whitelisted(addr, status);
    }

    /// @inheritdoc IProxyFactory
    function getProxyInitCodeHash() external view returns (bytes32) {
        return MASTER_PROXY_CLONE_CODE_HASH;
    }

    /// @inheritdoc IProxyFactory
    function getCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash,
        address thisAddress
    ) external pure returns (address) {
        /// @dev The result is same to Clones.predictDeterministicAddress(MASTER_PROXY, salt, address(this)), see tests
        return address(uint160(uint(keccak256(abi.encodePacked(bytes1(0xff), thisAddress, salt, initCodeHash)))));
    }

    /// @inheritdoc IProxyFactory
    function createNewProxy(address implementation, bytes memory data_) external returns (address proxy) {
        // there are no restrictions on who can call this function
        proxy = Clones.clone(address(MASTER_PROXY));
        _initProxy(proxy, implementation, data_);
    }

    /// @inheritdoc IProxyFactory
    function create2NewProxy(
        bytes32 salt,
        address implementation,
        bytes memory data_
    ) external onlyWhitelisted returns (address proxy) {
        proxy = Clones.cloneDeterministic(address(MASTER_PROXY), salt);
        _initProxy(proxy, implementation, data_);
    }

    function _initProxy(address proxy, address implementation, bytes memory data_) internal {
        IProxy(proxy).initProxy(implementation, data_);
        emit ProxyCreated(proxy);
    }

    function _onlyWhitelisted() internal view {
        require(whitelisted[msg.sender], NotWhitelisted());
    }
}
