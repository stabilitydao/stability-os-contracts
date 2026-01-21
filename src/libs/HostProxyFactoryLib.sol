// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IProxyFactory} from "../interfaces/IProxyFactory.sol";
import {IProxy} from "../interfaces/IProxy.sol";
import {IHostAccessManager} from "../interfaces/IHostAccessManager.sol";

library HostProxyFactoryLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    // keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostProxyFactoryLib")) - 1)) & ~bytes32(uint(0xff));
    bytes32 public constant HOST_PROXY_STORAGE_LOCATION = 0; // todo

    //region -------------------------------------- Data types
    error LogicNotFound(uint kind);

    event NewContractImplementation(uint kind, address seedToken);
    event ProxyDeployed(address proxy, address implementation, bytes payload);
    event ContractDeployed(address proxy, uint kind, bytes payload);

    /// @custom:storage-location erc7201:stability.host-contracts.HostProxyFactoryLib
    struct HostProxyFactoryStorage {
        /// @notice Current implementation of the given contracts
        mapping(uint contractKind => address logic) implementations;
    }
    //endregion -------------------------------------- Data types

    function contractImplementation(uint kind) external view returns (address) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        return $.implementations[kind];
    }

    function setContractImplementation(uint kind, address implementation) external {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        $.implementations[kind] = implementation;
        emit NewContractImplementation(kind, implementation);
    }

    //region -------------------------------------- Deploy actions
    /// @notice Deploy arbitrary proxy contract and initialize proxy and logic
    function deployProxy(
        bytes32 salt,
        address logic,
        bytes memory payload,
        address authority
    ) external returns (address proxy) {
        proxy = _deployAndInitProxy(salt, logic, payload, authority);
        emit ProxyDeployed(proxy, logic, payload);
    }

    /// @notice Deploy proxy-contract of the given kind, initialize the proxy and its logic
    /// @param kind See IHost.ContractKinds
    function deployContract(bytes32 salt, uint kind, bytes memory payload, address authority) external returns (address proxy) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();

        address logic = $.implementations[kind];
        require(logic != address(0), LogicNotFound(kind));

        proxy = _deployAndInitProxy(salt, logic, payload, authority);
        emit ContractDeployed(proxy, kind, payload);
    }
    //endregion -------------------------------------- Deploy actions

    //region -------------------------------------- Internal utils
    function _deployAndInitProxy(
        bytes32 salt,
        address logic,
        bytes memory payload,
        address authority
    ) internal returns (address proxy) {
        proxy = _createNewProxy(salt, IHostAccessManager(authority).PROXY_FACTORY());
        IProxy(proxy).initProxy(logic);
        IHosted(proxy).initialize(authority, payload);
        return proxy;
    }

    function getHostProxyFactoryStorage() internal pure returns (HostProxyFactoryStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := HOST_PROXY_STORAGE_LOCATION
        }
    }

    function _createNewProxy(bytes32 salt, address proxyFactory_) internal returns (address proxy) {
        proxy = salt == 0
            ? IProxyFactory(proxyFactory_).createNewProxy()
            : IProxyFactory(proxyFactory_).create2NewProxy(salt);
    }
    //endregion -------------------------------------- Internal utils
}
