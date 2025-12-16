// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOS} from "../interfaces/IOS.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol"; // todo upgradable

/// @notice Allow to create DAO and update its state according to life cycle
contract OS is IOS, AccessManager {
    constructor() {
        // todo
    }



}