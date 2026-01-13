// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostLib} from "./HostLib.sol";
import {IControllable2} from "../interfaces/IControllable2.sol";
import {IHostProxyFactory} from "../interfaces/IHostProxyFactory.sol";
import {Proxy} from "../base/Proxy.sol";
import {SeedToken} from "../tokenomics/SeedToken.sol";
import {TgeToken} from "../tokenomics/TgeToken.sol";

/// @notice Library for deploying tokens via HostProxyFactory
library HostDeployLib {
    function deploySeedToken(
        HostLib.OsStorage storage $,
        string memory token_,
        string memory symbol_
    ) internal returns (address) {
        bytes32 seed = 0; // todo
        return IHostProxyFactory($.osChainSettings[0].hostFactory).deploySeedToken(seed, abi.encode(token_, symbol_));
    }

    function deployTgeToken(
        HostLib.OsStorage storage $,
        string memory token_,
        string memory symbol_
    ) internal returns (address) {
        bytes32 seed = 0; // todo
        return IHostProxyFactory($.osChainSettings[0].hostFactory).deployTgeToken(seed, abi.encode(token_, symbol_));
    }
}
