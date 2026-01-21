// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

contract Authority is AccessManager, IAuthority {
    /// @inheritdoc IAuthority
    address public immutable HOST;

    /// @inheritdoc IAuthority
    address public immutable PROXY_FACTORY;

    constructor(address initialAdmin, address host_, address proxyFactory_) AccessManager(initialAdmin) {
        HOST = host_;
        PROXY_FACTORY = proxyFactory_;
    }
}
