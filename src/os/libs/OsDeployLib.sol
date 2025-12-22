// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {Proxy} from "../../core/proxy/Proxy.sol";

library OsDeployLib {
    function deployProxy(address accessManager, address logic) external returns (address) {
        Proxy proxy = new Proxy();
        proxy.initProxy(logic);

        // todo call logic.initialize(accessManager);
        accessManager;

        return address(proxy);
    }
}