// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostLib} from "./HostLib.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IHost} from "../interfaces/IHost.sol";
import {HostProxyDeployLib} from "./HostProxyDeployLib.sol";

/// @notice Library for deploying any contracts required by DAOs
library HostDeployLib {

    /// @notice Deploys the Seed Token contract for a DAO
    function deploySeedToken(
        HostLib.HostStorage storage $,
        uint daoUid,
        string memory token_,
        string memory symbol_,
        address authority_
    ) internal returns (address) {
        bytes32 seed = $.salt[HostLib.getKey(daoUid, uint16(ITokenomics.ContractIndices.SEED_TOKEN_1))];
        return HostProxyDeployLib.deployContract(
            seed, uint(IHost.ContractKinds.SEED_TOKEN_1), abi.encode(token_, symbol_), authority_
        );
    }

    /// @notice Deploys the TGE Token contract for a DAO
    function deployTgeToken(
        HostLib.HostStorage storage $,
        uint daoUid,
        string memory token_,
        string memory symbol_,
        address authority_
    ) internal returns (address) {
        bytes32 seed = $.salt[HostLib.getKey(daoUid, uint16(ITokenomics.ContractIndices.TGE_TOKEN_2))];
        return HostProxyDeployLib.deployContract(
            seed, uint(IHost.ContractKinds.TGE_TOKEN_2), abi.encode(token_, symbol_), authority_
        );
    }
}
