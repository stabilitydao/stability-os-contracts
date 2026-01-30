// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IUUPSUpgradable {
    /// @notice Upgrade the implementation of the proxy to `newImplementation`,
    /// and subsequently execute the function call encoded in `data`.
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}
