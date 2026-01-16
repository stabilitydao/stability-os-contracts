// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

interface IHostAccessManager is IAccessManager {
    /// @notice Address of Host contract on the current chain
    function HOST() external view returns (address);
}
