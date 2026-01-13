// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Controllable2} from "../core/base/Controllable2.sol";
import {IControllable2} from "../interfaces/IControllable2.sol";
import {IHostProxyFactory} from "../interfaces/IHostProxyFactory.sol";
import {IProxy} from "../interfaces/IProxy.sol";
import {Proxy} from "../core/proxy/Proxy.sol";

contract HostProxyFactory is Controllable2, IHostProxyFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    //region -------------------------------------- Constant
    /// @inheritdoc IControllable2
    string public constant VERSION = "1.0.0";

    // keccak256(abi.encode(uint(keccak256("erc7201:stability-os-contracts.HostProxyFactory")) - 1)) & ~bytes32(uint(0xff));
    bytes32 public constant HOST_STORAGE_LOCATION = 0xf89955ccc15fd1298e401a60272fc8444970d225cf711f81058f63f307199e00;

    //endregion -------------------------------------- Constants

    //region -------------------------------------- Initialization
    /// @inheritdoc IControllable2
    function initialize(
        address authority_,
        bytes memory /*payload*/
    ) public initializer {
        __Controllable_init(authority_);
    }

    //endregion -------------------------------------- Initialization

    //region -------------------------------------- View

    /// @inheritdoc IHostProxyFactory
    function getCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash,
        address thisAddress
    ) external pure returns (address) {
        return address(uint160(uint(keccak256(abi.encodePacked(bytes1(0xff), thisAddress, salt, initCodeHash)))));
    }

    /// @notice Get keccak256 hash of Proxy creationCode for CREATE2
    function getProxyInitCodeHash() external pure returns (bytes32) {
        return keccak256(type(Proxy).creationCode);
    }

    /// @notice Deployed seed tokens
    function seedTokens() external view returns (address[] memory) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        return $.seedTokens.values();
    }

    /// @notice Deployed tge tokens
    function tgeTokens() external view returns (address[] memory) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        return $.tgeTokens.values();
    }

    /// @inheritdoc IHostProxyFactory
    function seedTokenImplementation() external view returns (address) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        return $.seedTokenImplementation;
    }

    /// @inheritdoc IHostProxyFactory
    function tgeTokenImplementation() external view returns (address) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        return $.tgeTokenImplementation;
    }

    //endregion -------------------------------------- View

    //region -------------------------------------- Restricted actions
    /// @inheritdoc IHostProxyFactory
    function setSeedTokenImplementation(address implementation) external restricted {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        $.seedTokenImplementation = implementation;
        emit NewSeedTokenImplementation(implementation);
    }

    /// @inheritdoc IHostProxyFactory
    function setTgeTokenImplementation(address implementation) external restricted {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        $.tgeTokenImplementation = implementation;
        emit NewTgeTokenImplementation(implementation);
    }

    //endregion -------------------------------------- Restricted actions

    //region -------------------------------------- Deploy actions
    /// @inheritdoc IHostProxyFactory
    function deploySeedToken(bytes32 salt, bytes memory payload) external restricted returns (address proxy) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();

        proxy = address(new Proxy{salt: salt}());
        IProxy(proxy).initProxy($.seedTokenImplementation);
        IControllable2(proxy).initialize(authority(), payload);

        $.seedTokens.add(proxy);

        emit NewSeedToken(proxy, payload);
        return proxy;
    }

    /// @inheritdoc IHostProxyFactory
    function deployTgeToken(bytes32 salt, bytes memory payload) external restricted returns (address) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        address proxy = address(new Proxy{salt: salt}());
        IProxy(proxy).initProxy($.tgeTokenImplementation);
        IControllable2(proxy).initialize(authority(), payload);

        $.tgeTokens.add(proxy);

        emit NewTgeToken(proxy, payload);
        return proxy;
    }

    //endregion -------------------------------------- Deploy actions

    //region -------------------------------------- Internal utils
    function getHostProxyFactoryStorage() internal pure returns (HostProxyFactoryStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := HOST_STORAGE_LOCATION
        }
    }
    //endregion -------------------------------------- Internal utils
}
