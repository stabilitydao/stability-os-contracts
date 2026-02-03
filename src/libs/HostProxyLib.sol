// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IUUPSUpgradable} from "../interfaces/IUUPSUpgradable.sol";
import {IProxyFactory} from "../interfaces/IProxyFactory.sol";
import {IAuthority} from "../interfaces/IAuthority.sol";

/// @notice Announce and execute proxy upgrades
/// All proxies created by Host can be upgraded only with announced implementations after timelock
library HostProxyLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    // keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostProxyLib")) - 1)) & ~bytes32(uint(0xff));
    bytes32 public constant HOST_UPGRADE_STORAGE_LOCATION = 0xd39611a167548b62409d893b03e2cfda51ee7f22bb3b158652037b265ed0a600;

    //region -------------------------------------- Data types
    /// @dev Data announced for next host platform upgrade
    struct HostUpgradeData {
        /// @dev Next host version, format yyyy.mm.dd
        string newVersion;
        /// @dev Proxies to be upgraded
        address[] proxies;
        /// @dev New implementations for proxies
        address[] newImplementations;
    }

    /// @custom:storage-location erc7201:stability.host-contracts.HostProxyLib
    struct HostProxyStorage {
        /// @notice Current implementation of the given contracts
        mapping(uint contractKind => address logic) implementations;

        /// @dev Announced pending host upgrade data
        HostUpgradeData pendingPlatformUpgrade;
        /// @dev Timestamp when timelock for announced upgrade ends
        uint platformUpgradeTimeLock;
        /// @dev Current host version
        string platformVersion;
    }

    //endregion -------------------------------------- Data types

    //region -------------------------------------- Deploy logic
    function contractImplementation(uint kind) external view returns (address) {
        HostProxyStorage storage $ = getHostProxyStorage();
        return $.implementations[kind];
    }

    function setContractImplementation(uint kind, address implementation) external {
        HostProxyStorage storage $ = getHostProxyStorage();
        $.implementations[kind] = implementation;
        emit IHost.NewContractImplementation(kind, implementation);
    }

    /// @notice Deploy arbitrary proxy contract and initialize proxy and logic
    function deployProxy(
        bytes32 salt,
        address logic,
        bytes memory payload,
        address authority
    ) external returns (address proxy) {
        proxy = _deployAndInitProxy(salt, logic, payload, authority);
        emit IHost.ProxyDeployed(proxy, logic, payload);
    }

    /// @notice Deploy proxy-contract of the given kind, initialize the proxy and its logic
    /// @param kind See IHost.ContractKinds
    function deployContract(
        bytes32 salt,
        uint kind,
        bytes memory payload,
        address authority
    ) external returns (address proxy) {
        HostProxyStorage storage $ = getHostProxyStorage();

        address logic = $.implementations[kind];
        require(logic != address(0), IHost.LogicNotFound(kind));

        proxy = _deployAndInitProxy(salt, logic, payload, authority);
        emit IHost.ContractDeployed(proxy, kind, payload);
    }
    //endregion -------------------------------------- Deploy logic

    //region -------------------------------------- Upgrade logic

    /// @notice Set initial host platform version
    function initialize(string memory version) external {
        HostProxyStorage storage $ = getHostProxyStorage();
        $.platformVersion = version;
        emit IHost.HostVersion(version);
    }

    /// @notice Announce platform upgrade with new implementations for proxies
    function announceUpgrade(
        string memory newVersion,
        address[] memory proxies,
        address[] memory newImplementations
    ) external {
        HostProxyStorage storage $ = getHostProxyStorage();
        IHost.HostChainSettings storage hostStorage = HostConfigLib.getHostChainSettings();
        require($.pendingPlatformUpgrade.proxies.length == 0, IHost.AlreadyAnnounced());
        uint len = proxies.length;
        require(len == newImplementations.length, IHost.IncorrectArrayLengths());

        for (uint i; i < len; ++i) {
            require(proxies[i] != address(0) && newImplementations[i] != address(0), IHosted.IncorrectZeroArgument());
            //slither-disable-next-line calls-loop
            require(!_eq(IHosted(proxies[i]).VERSION(), IHosted(newImplementations[i]).VERSION()), IHost.SameVersion());
        }

        string memory oldVersion = $.platformVersion;
        require(!_eq(oldVersion, newVersion), IHost.SameVersion());

        $.pendingPlatformUpgrade.newVersion = newVersion;
        $.pendingPlatformUpgrade.proxies = proxies;
        $.pendingPlatformUpgrade.newImplementations = newImplementations;
        uint tl = block.timestamp + hostStorage.timelock;
        $.platformUpgradeTimeLock = tl;

        emit IHost.UpgradeAnnounce(oldVersion, newVersion, proxies, newImplementations, tl);
    }

    /// @notice Execute announced upgrade after timelock
    function upgrade() external {
        HostProxyStorage storage $ = getHostProxyStorage();
        uint ts = $.platformUpgradeTimeLock;
        require(ts != 0, IHost.NoNewVersion());
        //slither-disable-next-line timestamp
        require(block.timestamp > ts, IHost.UpgradeTimerIsNotOver(ts));
        HostUpgradeData memory platformUpgrade = $.pendingPlatformUpgrade;
        uint len = platformUpgrade.proxies.length;
        // nosemgrep
        for (uint i; i < len; ++i) {
            //slither-disable-next-line calls-loop
            string memory oldContractVersion = IHosted(platformUpgrade.proxies[i]).VERSION();
            //slither-disable-next-line calls-loop
            IUUPSUpgradable(platformUpgrade.proxies[i]).upgradeToAndCall(platformUpgrade.newImplementations[i], "");
            //slither-disable-next-line calls-loop reentrancy-events
            emit IHost.ProxyUpgraded(
                platformUpgrade.proxies[i],
                platformUpgrade.newImplementations[i],
                oldContractVersion,
                IHosted(platformUpgrade.proxies[i]).VERSION()
            );
        }
        $.platformVersion = platformUpgrade.newVersion;
        delete $.pendingPlatformUpgrade;
        $.platformUpgradeTimeLock = 0;

        //slither-disable-next-line reentrancy-events
        emit IHost.HostVersion(platformUpgrade.newVersion);
    }

    /// @notice Cancel announced upgrade
    function cancelUpgrade() external {
        HostProxyStorage storage $ = getHostProxyStorage();
        require($.platformUpgradeTimeLock != 0, IHost.NoNewVersion());
        emit IHost.CancelUpgrade(IHosted(address(this)).VERSION(), $.pendingPlatformUpgrade.newVersion);
        delete $.pendingPlatformUpgrade;
        $.platformUpgradeTimeLock = 0;
    }

    /// @notice Get current host platform version
    function hostVersion() external view returns (string memory) {
        HostProxyStorage storage $ = getHostProxyStorage();
        return $.platformVersion;
    }

    /// @notice Get announced pending platform upgrade data
    function pendingUpgrade()
        external
        view
        returns (string memory newVersion, address[] memory proxies, address[] memory newImplementations)
    {
        HostProxyStorage storage $ = getHostProxyStorage();
        HostUpgradeData memory data = $.pendingPlatformUpgrade;
        return (data.newVersion, data.proxies, data.newImplementations);
    }

    //endregion -------------------------------------- Upgrade logic

    //region -------------------------------------- Internal utils
    function _deployAndInitProxy(
        bytes32 salt,
        address logic,
        bytes memory payload,
        address authority
    ) internal returns (address proxy) {
        proxy = _createNewProxy(salt, IAuthority(authority).PROXY_FACTORY(), logic);
        IHosted(proxy).initialize(authority, payload);
        return proxy;
    }

    function _createNewProxy(bytes32 salt, address proxyFactory_, address logic) internal returns (address proxy) {
        proxy = salt == 0
            ? IProxyFactory(proxyFactory_).createNewProxy(logic, "")
            : IProxyFactory(proxyFactory_).create2NewProxy(salt, logic, "");
    }

    function _eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function getHostProxyStorage() private pure returns (HostProxyStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := HOST_UPGRADE_STORAGE_LOCATION
        }
    }
    //endregion -------------------------------------- Internal utils
}
