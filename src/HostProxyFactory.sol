// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Hosted} from "./base/Hosted.sol";
import {IHosted} from "./interfaces/IHosted.sol";
import {IHostProxyFactory} from "./interfaces/IHostProxyFactory.sol";
import {IERC1967ProxyFactory} from "./interfaces/IERC1967ProxyFactory.sol";

contract HostProxyFactory is Hosted, IHostProxyFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    //region -------------------------------------- Constant
    /// @inheritdoc IHosted
    string public constant VERSION = "1.0.0";

    // keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostProxyFactory")) - 1)) & ~bytes32(uint(0xff));
    bytes32 public constant HOST_PROXY_STORAGE_LOCATION =
        0x6e1ec94684dca8034e98f557b164c745fd4b39d7b8f15d7f0549b34b10dd8a00;

    /// @inheritdoc IHostProxyFactory
    address public immutable ERC1967_PROXY_FACTORY;

    //endregion -------------------------------------- Constants

    //region -------------------------------------- Initialization
    /// @param erc1967ProxyFactory_ Address of deployed ERC1967ProxyFactory. This factory is used to deploy all proxies.
    constructor(address erc1967ProxyFactory_) {
        ERC1967_PROXY_FACTORY = erc1967ProxyFactory_;
    }

    /// @inheritdoc IHosted
    function initialize(address authority_, bytes memory /*payload*/) public initializer {
        __Controllable_init(authority_);
    }

    //endregion -------------------------------------- Initialization

    //region -------------------------------------- View
    /// @inheritdoc IHostProxyFactory
    function seedTokens() external view returns (address[] memory) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        return $.seedTokens.values();
    }

    /// @inheritdoc IHostProxyFactory
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
    function deployProxy(
        bytes32 salt,
        address logic,
        bytes memory payload
    ) external restricted returns (address proxy) {
        proxy = _createNewProxy(salt, logic);
        IHosted(proxy).initialize(authority(), payload);

        emit NewContractDeployed(proxy, logic, payload);
        return proxy;
    }

    /// @inheritdoc IHostProxyFactory
    function deploySeedToken(bytes32 salt, bytes memory payload) external restricted returns (address proxy) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();

        proxy = _createNewProxy(salt, $.seedTokenImplementation);
        IHosted(proxy).initialize(authority(), payload);

        $.seedTokens.add(proxy);

        emit NewSeedToken(proxy, payload);
        return proxy;
    }

    /// @inheritdoc IHostProxyFactory
    function deployTgeToken(bytes32 salt, bytes memory payload) external restricted returns (address) {
        HostProxyFactoryStorage storage $ = getHostProxyFactoryStorage();
        address proxy = _createNewProxy(salt, $.tgeTokenImplementation);
        IHosted(proxy).initialize(authority(), payload);

        $.tgeTokens.add(proxy);

        emit NewTgeToken(proxy, payload);
        return proxy;
    }

    //endregion -------------------------------------- Deploy actions

    //region -------------------------------------- Internal utils
    function getHostProxyFactoryStorage() internal pure returns (HostProxyFactoryStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := HOST_PROXY_STORAGE_LOCATION
        }
    }

    function _createNewProxy(bytes32 salt, address implementation) internal returns (address proxy) {
        proxy = salt == 0
            ? IERC1967ProxyFactory(ERC1967_PROXY_FACTORY).createNewProxy(implementation, "")
            : IERC1967ProxyFactory(ERC1967_PROXY_FACTORY).create2NewProxy(salt, implementation, "");
    }
    //endregion -------------------------------------- Internal utils
}
