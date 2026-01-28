// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "./ITokenomics.sol";

/// @notice All data types related to bridged actions
interface IBridgedActions {

    /// @notice Input data for IHost.BridgedActions.BRIDGE_DAO_1 action. DAO must be in not-live phase.
    struct BridgeDaoParams {
        /// @notice Symbol of the DAO token
        string symbol;

        /// @notice Name of the DAO, used in token names. Without DAO word.
        string name;

        /// @notice IDs of he units. At least one unit must be provided.
        string[] unitIds;

        /// @notice Chain-related DAO settings (individual for each chain)
        ITokenomics.DaoChainSettings chainSettings;

        /// @notice DAO parameters (same for all chains where DAO is bridged)
        ITokenomics.DaoParameters daoParameters;

        /// @notice ITokenomicsAddons.ContractIndices - list of contract for which {salts} are provided
        uint16[] saltContractIndices;

        /// @notice Salts for deploying DAO contracts on bridged chain. Array should be sync with {saltContractIndices}
        bytes32[] salts;
    }

}
