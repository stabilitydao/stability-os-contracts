// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDAOUnit {
    /// @notice Unit status can be changed automatically on DAO lifecycle phase changes or manually by DAO holders.
    enum UnitStatus {
        /// @notice Researching state.
        RESEARCH_0,
        /// @notice Building / development state.
        BUILDING_1,
        /// @notice Live and earning revenue.
        LIVE_2
    }

    /// @notice Supported categories of running units.
    enum UnitComponentCategory {
        /// @notice Chain support (blockchain integrations, relayers).
        CHAIN_SUPPORT_0,
        /// @notice Engine support (infrastructure and execution engine).
        ENGINE_SUPPORT_1,
        /// @notice DeFi strategy components.
        DEFI_STRATEGY_2,
        /// @notice MEV strategy components.
        MEV_STRATEGY_3
    }

    /// @notice Supported unit types.
    enum UnitType {
        /// @notice VE-token early exit fees
        PVP_0,
        /// @notice Decentralized finance protocol
        DEFI_PROTOCOL_1,
        /// @notice Software as a Service business
        SAAS_2,
        /// @notice Maximum Extractable Value tool
        MEV_3
    }

    /// @notice Frontend endpoint link for a Unit.
    struct UnitUiLink {
        /// @notice Short label for the UI link.
        string label;
        /// @notice URL of the frontend endpoint.
        string url;
        // Attention: there is NO gap here so the struct is NOT extendable
    }

    /// @notice Revenue generating unit owned by a DAO.
    struct UnitInfo {
        /// @notice Unique unit string id. For DeFi protocol its defiOrg:protocolKey.
        string unitId;
        /// @notice Short name of the unit.
        string name;
        /// @notice Status of unit changes appear when unit starting to work and starting earning revenue.
        UnitStatus status;
        /// @notice Supported type of the Unit represented as UnitType
        uint16 unitType;
        /// @notice The share of a Unit's profit received by the DAO to which it belongs. 100_000 - 100%.
        uint revenueShare;
        /// @notice A unique emoji for the shortest possible representation of a Unit in the Stability OS.
        string emoji;
        /// @notice Frontend endpoints of Unit.
        UnitUiLink[] ui;
        /// @notice Links to API of the Unit.
        string[] api;
        // Attention: Don't forget to increment OsEncodingLib.UNIT_STRUCT_VERSION if you add new fields here
    }
}
