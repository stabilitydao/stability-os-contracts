// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Additional data types (not implemented in prototypes). Todo move to ITokenomics
interface ITokenomicsAddons {
    /// @notice Indices of all contracts that can be deployed by a DAO. The indices are used to pre-set salts
    enum ContractIndices {
        NOT_USED_0,
        SEED_TOKEN_1,
        TGE_TOKEN_2,
        TOKEN_3,
        X_TOKEN_4,
        DAO_TOKEN_5,
        STAKING_6,
        RECOVERY_7,
        TOKEN_BRIDGE_8,
        X_TOKEN_BRIDGE_9,
        DAO_TOKEN_BRIDGE_10,
        VESTING_1_11,
        VESTING_2_12,
        VESTING_3_13,
        VESTING_4_14,
        VESTING_5_15,
        VESTING_6_16,
        VESTING_7_17,
        VESTING_8_18,
        VESTING_9_19,
        VESTING_10_20,
        REVENUE_ROUTER_21,

        // add new indices here if necessary

        COUNT_CONTRACT_INDICES
    }
}
