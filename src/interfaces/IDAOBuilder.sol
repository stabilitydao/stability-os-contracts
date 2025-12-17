// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDAOBuilder {
    /// @notice  Engineer hired by a DAO. Can be human or machine (AI agent).
    struct Worker {
        /// @notice Github username
        string github;
        /// @notice USD hourly rate
        uint256 rate;
        /// @notice USD xTOKEN hourly rate
        uint256 xRate;
    }

    /// @notice Pool of development tasks. A set of open github issues.
    struct Pool {
        /// @notice Pool is always linked to a set of units.
        string[] unitIds;
        /// @notice Short name of the pool.
        string name;
        /// @notice Label on github repositories identifying relation to the pool.
        GithubLabel label;
        /// @notice What need to be done by the pool?
        string description;
        /// @notice Each solved task in the pool must have an artifact of specified type.
        ArtifactType[] artifacts;
    }

    /// @notice Conveyor belt for building a components for units.
    struct Conveyor {
        /// @notice Linked unit
        string unitId;
        /// @notice UnitComponentCategory imported from project; represented here as uint8
        uint8 componentCategory;
        string name;
        string symbol;
        string conveyorType;
        GithubLabel label;
        string description;
        string issueTitleTemplate;
        string taskIdIs;
        ConveyorStep[] steps;
    }

    struct GithubLabel {
        string name;
        string description;
        string color;

        // todo add gap to be able to add new fields
    }

    struct GithubUser {
        string username;
        string img;
    }

    struct GithubIssue {
        string repo;
        uint256 id;
        string title;
        GithubLabel[] labels;
        GithubUser assignees;
        string body;
    }

    enum ArtifactType {
        URL_UI_0,
        URL_RELEASE_1,
        DEPLOYMENT_ADDRESSES_2,
        URL_API_3,
        URL_STATIC_4,
        CONTRACT_ADDRESS_5
    }

    struct IssueTemplate {
        string repo;
        string[] taskList;
        string issueTemplate;
        string body;
        string generator;
        // todo add gap to be able to add new fields
    }

    struct ConveyorStep {
        string name;
        IssueTemplate[] issues;
        ArtifactType[] artifacts;
        string result;
        string guide;
        // todo add gap to be able to add new fields
    }

    struct BuildersMemoryEntry {
        /// @notice mapping from repo => total open issues count
        mapping(string repo => uint256 total) totalOpenIssues;
        /// @notice mapping from poolName => array of issues
        mapping(string poolName => GithubIssue[]) poolIssues;
        /// @notice mapping from conveyorName => mapping(taskId => mapping(stepName => issues[]))
        mapping(string => mapping(string => mapping(string => GithubIssue[]))) conveyors;
    }

    /// @notice Total salaries paid
    struct BurnRate {
        /// @notice Period of burning. Can be 1 month or any other.
        string period;

        /// @notice How much USD was spent during period.
        uint256 usdAmount;
    }

    /// @notice BUILDER activity record.
    struct BuilderActivity {
        /// @notice Safe multisig account(s) of dev team.
        address[] multisig;

        /// @notice Tracked Github repositories where development going on.
        string[] repo;

        /// @notice Engineers.
        Worker[] workers;

        /// @notice Conveyors of unit components.
        Conveyor[] conveyors;

        /// @notice Pools of development tasks.
        Pool[] pools;

        /// @notice Total salaries / burn rates paid.
        BurnRate[] burnRate;
    }
}