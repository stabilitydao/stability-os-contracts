// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";

/// @notice Allow to create DAO and update its state according to life cycle
interface IOS {
    error NameLength(uint length);
    error SymbolLength(uint length);
    error SymbolNotUnique(string symbol);
    error PvPFee(uint value);
    error TooLateToUpdateSuchFunding();
    error TooLateToUpdateVesting();
    error NeedFunding();
    error VePeriod(uint period);

    event DaoCreated(
        string name,
        string daoSymbol,
        ITokenomics.Activity[] activity,
        ITokenomics.DaoParameters params,
        ITokenomics.Funding[] funding
    );

    event OsSettingsUpdated(IOS.OsSettings st);

    /// @notice todo add comments
    struct OsSettings {
        uint priceDao;
        uint priceUnit;
        uint priceOracle;
        uint priceBridge;
        uint minNameLength;
        uint maxNameLength;
        uint minSymbolLength;
        uint maxSymbolLength;
        uint minVePeriod;
        uint maxVePeriod;
        uint minPvPFee;
        uint maxPvPFee;
        uint minFundingDuration;
        uint maxFundingDuration;
        uint minAbsorbOfferUsd;
        /// @notice todo Move to chain-depended config. The address of the asset used to fund the DAO.
        // todo address exchangeAsset;
    }

    struct Task {
        string name;
    }

    /// @notice Kinds of cross-chain messages
    enum CrossChainMessages {
        NEW_DAO_SYMBOL_0,
        DAO_RENAME_SYMBOL_1,
        DAO_BRIDGED_2
    }

    //region ---------------------------------------- Read

    function settings() external view returns (OsSettings memory);

    /// @notice Local DAOs storage (in form of a mapping)
    function getDAO(string calldata daoSymbol) external view returns (ITokenomics.DaoData memory);

    /// @notice Owner of the DAO
    function getDAOOwner(string calldata daoSymbol) external view returns (address);

    /// @notice True if a DAO with such symbol already exists
    function isDaoSymbolInUse(string calldata daoSymbol) external view returns (bool);

    /// @notice Get full list of DAOs symbols registered in any chains
    function getListDAO() external view returns (string[] memory daoSymbols);

    /// @notice Governance proposals. Can be created only at initialChain of DAO.
    function proposals(string calldata proposalId) external view returns (ITokenomics.Proposal memory);

    /// @notice Generate list of tasks that should be performed on the current phase
    function tasks(string calldata daoSymbol) external view returns (Task[] memory);

    /// @notice Get OS settings
    function getSettings() external view returns (OsSettings memory);
    //endregion ---------------------------------------- Read

    //region ---------------------------------------- Write actions

    /// @notice Set OS settings
    function setSettings(OsSettings memory newSettings) external;


    /// @notice Create new DAO
    /// @param name Name of new DAO (any name is allowed)
    /// @param daoSymbol Symbol of new DAO (should be unique across all DAOs, it can be changed later)
    /// @param activity List of activities of the DAO
    /// @param params On-chain DAO parameters
    /// @param funding Initial funding rounds of the DAO
    function createDAO(
        string calldata name,
        string calldata daoSymbol,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) external;

    /// @notice Add live compatible DAO
    function addLiveDAO(ITokenomics.DaoData memory dao) external;

    /// @notice Change lifecycle phase of a DAO
    /// @custom:restricted Restricted through access manager
    function changePhase(string calldata daoSymbol) external;

    /// @notice Provide funding to the DAO, receive seed or tge tokens in return
    function fund(string calldata daoSymbol, uint256 amount) external;

    /// @notice Process voting results from governance
    /// @custom:restricted Restricted through access manager
    function receiveVotingResults(string calldata proposalId, bool succeed) external;

    //endregion ---------------------------------------- Write actions

    //region ---------------------------------------- Update actions

    /// @notice Update/create proposal to update implementations of the DAO contracts
    function updateImages(string calldata daoSymbol, ITokenomics.DaoImages calldata images) external;

    /// @notice Update/create proposal to update list of socials of the DAO
    function updateSocials(string calldata daoSymbol, string[] calldata socials) external;

    /// @notice Update/create proposal to update tokenomics units of the DAO
    function updateUnits(string calldata daoSymbol, ITokenomics.UnitInfo[] calldata units) external;

    /// @notice Update/create proposal to update funding rounds of the DAO
    function updateFunding(string calldata daoSymbol, ITokenomics.Funding calldata funding) external;

    /// @notice Update/create proposal to update vesting schedules of the DAO
    function updateVesting(string calldata daoSymbol, ITokenomics.Vesting[] calldata vestings) external;

    /// @notice Update/create proposal to update DAO naming (name and symbol)
    function updateNaming(string calldata daoSymbol, ITokenomics.DaoNames calldata daoNames_) external;

    /// @notice Update/create proposal to update on-chain DAO parameters
    function updateDaoParameters(string calldata daoSymbol, ITokenomics.DaoParameters calldata daoParameters_) external;

    //endregion ---------------------------------------- Update actions
}
