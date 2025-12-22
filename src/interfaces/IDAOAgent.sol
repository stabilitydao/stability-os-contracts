// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDAOAgent {
    enum AgentRole {
        OPERATOR_0
    }

    /// @notice Representation of an agent (off-chain actor/service) in the system.
    struct AgentInfo {
        /// @notice Array of API endpoint URLs for the agent.
        string[] api;
        /// @notice Roles of the agent represented as `uint8` values (use a project-specific enum elsewhere).
        uint8[] roles;
        /// @notice Human-readable name of the agent.
        string name;
        /// @notice Operational directives or notes for the agent.
        string[] directives;
        /// @notice Link to agent image (URL or IPFS).
        string image;
        /// @notice Telegram handle, expected to start with `@`.
        string telegram;
    }
}
