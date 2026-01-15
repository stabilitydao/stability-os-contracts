// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostLib} from "./HostLib.sol";
import {IHostProxyFactory} from "../interfaces/IHostProxyFactory.sol";
import {ITokenomicsAddons} from "../interfaces/ITokenomicsAddons.sol";
import {HostConfigLib} from "./HostConfigLib.sol";

/// @notice Library for deploying tokens via HostProxyFactory
library HostDeployLib {
    function deploySeedToken(
        HostLib.HostStorage storage $,
        uint daoUid,
        string memory token_,
        string memory symbol_
    ) internal returns (address) {
        bytes32 seed = $.salt[
            HostLib.getKey(daoUid, uint16(ITokenomicsAddons.ContractIndices.SEED_TOKEN_1), block.chainid)
        ];
        return IHostProxyFactory(HostConfigLib.getHostChainSettings().hostFactory).deploySeedToken(seed, abi.encode(token_, symbol_));
    }

    function deployTgeToken(
        HostLib.HostStorage storage $,
        uint daoUid,
        string memory token_,
        string memory symbol_
    ) internal returns (address) {
        bytes32 seed = $.salt[
            HostLib.getKey(daoUid, uint16(ITokenomicsAddons.ContractIndices.TGE_TOKEN_2), block.chainid)
        ];
        return IHostProxyFactory(HostConfigLib.getHostChainSettings().hostFactory).deployTgeToken(seed, abi.encode(token_, symbol_));
    }
}
