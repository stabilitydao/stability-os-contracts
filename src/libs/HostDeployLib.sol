// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostLib} from "./HostLib.sol";
import {ITokenomicsAddons} from "../interfaces/ITokenomicsAddons.sol";
import {IHost} from "../interfaces/IHost.sol";
import {HostProxyFactoryLib} from "./HostProxyFactoryLib.sol";

/// @notice Library for deploying tokens via HostProxyFactory
library HostDeployLib {
    function deploySeedToken(
        HostLib.HostStorage storage $,
        uint daoUid,
        string memory token_,
        string memory symbol_,
        address authority_
    ) internal returns (address) {
        bytes32 seed = $.salt[
            HostLib.getKey(daoUid, uint16(ITokenomicsAddons.ContractIndices.SEED_TOKEN_1), block.chainid)
        ];
        return HostProxyFactoryLib.deployContract(seed, uint(IHost.ContractKinds.SEED_TOKEN_1), abi.encode(token_, symbol_), authority_);
    }

    function deployTgeToken(
        HostLib.HostStorage storage $,
        uint daoUid,
        string memory token_,
        string memory symbol_,
        address authority_
    ) internal returns (address) {
        bytes32 seed = $.salt[
            HostLib.getKey(daoUid, uint16(ITokenomicsAddons.ContractIndices.TGE_TOKEN_2), block.chainid)
        ];
        return HostProxyFactoryLib.deployContract(seed, uint(IHost.ContractKinds.TGE_TOKEN_2), abi.encode(token_, symbol_), authority_);
    }
}
