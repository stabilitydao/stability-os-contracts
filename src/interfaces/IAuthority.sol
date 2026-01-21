// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

interface IAuthority is IAccessManager {
    /// @notice Address of Host contract on the current chain
    function HOST() external view returns (address);

    /// @notice Address of ProxyFactory used to deploy the proxy contracts
    function PROXY_FACTORY() external view returns (address);
}
