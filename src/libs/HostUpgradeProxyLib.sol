// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHost} from "../interfaces/IHost.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IUUPSUpgradable} from "../interfaces/IUUPSUpgradable.sol";

/// @notice Announce and execute proxy upgrades
library HostUpgradeProxyLib {
    // keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostUpgradeProxyLib")) - 1)) & ~bytes32(uint(0xff));
    bytes32 public constant HOST_UPGRADE_STORAGE_LOCATION = 0; // todo

    uint public constant TIME_LOCK = 30 minutes; // todo

    struct HostUpgradeData {
        string newVersion;
        address[] proxies;
        address[] newImplementations;
    }

    /// @custom:storage-location erc7201:stability.host-contracts.HostUpgradeProxyLib
    struct HostUpgradeProxyStorage {
        HostUpgradeData pendingPlatformUpgrade;
        uint platformUpgradeTimelock;
        string platformVersion;
    }

    function initialize(string memory version) external {
        HostUpgradeProxyStorage storage $ = _getStorage();
        $.platformVersion = version;
        emit IHost.HostVersion(version);
    }

    function announceUpgrade(
        string memory newVersion,
        address[] memory proxies,
        address[] memory newImplementations
    ) external {
        HostUpgradeProxyStorage storage $ = _getStorage();
        require($.pendingPlatformUpgrade.proxies.length == 0, IHost.AlreadyAnnounced());
        uint len = proxies.length;
        require(len == newImplementations.length, IHost.IncorrectArrayLengths());

        for (uint i; i < len; ++i) {
            require(proxies[i] != address(0), IHosted.IncorrectZeroArgument());
            require(newImplementations[i] != address(0), IHosted.IncorrectZeroArgument());
            //slither-disable-next-line calls-loop
            require(!_eq(IHosted(proxies[i]).VERSION(), IHosted(newImplementations[i]).VERSION()), IHost.SameVersion());
        }
        string memory oldVersion = $.platformVersion;
        require(!_eq(oldVersion, newVersion), IHost.SameVersion());
        $.pendingPlatformUpgrade.newVersion = newVersion;
        $.pendingPlatformUpgrade.proxies = proxies;
        $.pendingPlatformUpgrade.newImplementations = newImplementations;
        uint tl = block.timestamp + TIME_LOCK;
        $.platformUpgradeTimelock = tl;
        emit IHost.UpgradeAnnounce(oldVersion, newVersion, proxies, newImplementations, tl);
    }

    function upgrade() external {
        HostUpgradeProxyStorage storage $ = _getStorage();
        uint ts = $.platformUpgradeTimelock;
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
        $.pendingPlatformUpgrade.newVersion = "";
        $.pendingPlatformUpgrade.proxies = new address[](0);
        $.pendingPlatformUpgrade.newImplementations = new address[](0);
        $.platformUpgradeTimelock = 0;

        //slither-disable-next-line reentrancy-events
        emit IHost.HostVersion(platformUpgrade.newVersion);
    }

    function cancelUpgrade() external {
        HostUpgradeProxyStorage storage $ = _getStorage();
        require($.platformUpgradeTimelock != 0, IHost.NoNewVersion());
        emit IHost.CancelUpgrade(IHosted(address(this)).VERSION(), $.pendingPlatformUpgrade.newVersion);
        $.pendingPlatformUpgrade.newVersion = "";
        $.pendingPlatformUpgrade.proxies = new address[](0);
        $.pendingPlatformUpgrade.newImplementations = new address[](0);
        $.platformUpgradeTimelock = 0;
    }

    function hostVersion() external view returns (string memory) {
        HostUpgradeProxyStorage storage $ = _getStorage();
        return $.platformVersion;
    }

    function pendingPlatformUpgrade()
        external
        view
        returns (string memory newVersion, address[] memory proxies, address[] memory newImplementations)
    {
        HostUpgradeProxyStorage storage $ = _getStorage();
        HostUpgradeData memory data = $.pendingPlatformUpgrade;
        return (data.newVersion, data.proxies, data.newImplementations);
    }

    function _eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _getStorage() private pure returns (HostUpgradeProxyStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := HOST_UPGRADE_STORAGE_LOCATION
        }
    }
}
