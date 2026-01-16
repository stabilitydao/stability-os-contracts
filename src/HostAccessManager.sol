// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

contract HostAccessManager is AccessManager {
    /// @notice Address of Host contract on the current chain
    address public immutable HOST;

    constructor(address initialAdmin, address host_) AccessManager(initialAdmin) {
        HOST = host_;
    }
}
