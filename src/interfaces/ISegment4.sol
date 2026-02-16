// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice All data emitted in events and not stored on chain
interface ISegment4 {
    /// @notice Unit status can be changed manually by DAO holders. Revenue of a unit matter.
    enum UnitStatus {
        /// @notice Researching state.
        RESEARCH_0,
        BUILDING_PROTOTYPE_1,
        PROTOTYPE_2,
        /// @notice Building / development state.
        BUILDING_3,
        /// @notice Live and earning revenue.
        LIVE_4
    }

    /// @notice Supported unit types.
    enum UnitType {
        /// @notice VE-token early exit fees
        PVP_0,
        /// @notice Decentralized finance protocol
        DEFI_PROTOCOL_1,
        /// @notice Maximum Extractable Value tool
        MEV_SEARCHER_2
        /// @notice Software as a Service business
        // SAAS_3
    }

    /// @notice Frontend endpoint link for a Unit.
    struct UnitUiLink {
        /// @notice URL of the frontend endpoint.
        string href;
        /// @notice Short label for the UI link.
        string title;
        // Attention: there is NO gap here so the struct is NOT extendable
    }

    struct GithubLabel {
        string name;
        string description;
        string color;
    }

    /// @notice Pool of development tasks for Unit. A set of open github issues.
    struct UnitPool {
        string[] repos;
        /// @notice Label on github repositories identifying relation to the pool.
        GithubLabel label;
        string contractorSymbol;
    }

    /// @notice Off-chain data of the Unit. It's just emitted in event
    struct UnitEmitData {
        /// @notice Short name of the unit.
        string name;
        /// @notice Description of the unit
        string description;
        /// @notice Status of unit changes appear when unit starting to work and starting earning revenue.
        UnitStatus status;
        /// @notice Supported type of the Unit represented as UnitType
        UnitType unitType;
        /// @notice The share of a Unit's profit received by the DAO to which it belongs. 100_000 - 100%.
        uint revenueShare;
        /// @notice A unique emoji for the shortest possible representation of a Unit in the Stability OS.
        string emoji;
        /// @notice Frontend endpoints of Unit.
        UnitUiLink[] ui;
        /// @notice Links to API of the Unit.
        string[] api;
        /// @notice Pool of development tasks for Unit. A set of open github issues.
        UnitPool pool;
    }
}
