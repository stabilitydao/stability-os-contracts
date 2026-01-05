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
    error SolveTasksFirst();
    error WaitFundingStart();
    error WaitFundingEnd();
    error TooLateSoSetupFundingAgain();
    error WaitVestingStart();
    error WaitVestingEnd();
    error NotFundingPhase();
    error RaiseMaxExceed();
    error AlreadyReceived();
    error IncorrectProposal();
    error NonImplemented();
    error YouAreNotOwnerOf(string daoSymbol);
    error IncorrectDao();
    error ZeroBalance();
    error NotRefundPhase();
    error UnsupportedStructVersion();

    event DaoCreated(string name, string daoSymbol, uint daoUid);

    event OsSettingsUpdated(IOS.OsSettings st);
    event OsChainSettingsUpdated(IOS.OsChainSettings st);
    event DaoImagesUpdated(string daoSymbol, ITokenomics.DaoImages images);
    event DaoSocialsUpdated(string daoSymbol, string[] socials);
    event DaoUnitsUpdated(string daoSymbol, ITokenomics.UnitInfo[] units);
    event DaoFundingUpdated(string daoSymbol, ITokenomics.Funding funding);
    event DaoVestingUpdated(string daoSymbol, ITokenomics.Vesting[] vestings);
    event DaoNamingUpdated(string daoSymbol, ITokenomics.DaoNames daoNames);
    event DaoParametersUpdated(string daoSymbol, ITokenomics.DaoParameters daoParameters);
    event DaoPhaseChanged(string daoSymbol, ITokenomics.LifecyclePhase newPhase);
    event DaoFunded(string daoSymbol, address funder, uint amount, uint8 fundingType);
    event DaoRefunded(string daoSymbol, address funder, address asset, uint amount, uint8 fundingType);
    event OnRegisterDaoSymbol(string daoSymbol, uint32 srcEid, bytes32 guid_);
    event OnRenameDaoSymbol(string oldSymbol, string newSymbol, uint32 srcEid, bytes32 guid_);

    error NotEnoughNativeProvided(uint requiredValue);

    /// @notice DAO-setting common for all chains
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

        /// @notice Maximum delay (in seconds) before the seed funding round can start after DAO creation.
        uint maxSeedStartDelay;
    }

    /// @notice Chain-dependent data of the DAO
    struct OsChainSettings {
        /// @notice The address of the asset used to fund the DAO.
        address exchangeAsset;

        /// @notice Address of the OS bridge contract on the current chain
        address osBridge;
    }

    struct Task {
        string name;
    }

    /// @notice Payload for OS initialization
    struct OsInitPayload {
        /// @notice DAO symbols registered on other chains
        string[] usedSymbols;
    }

    /// @notice Kinds of cross-chain messages
    enum CrossChainMessages {
        NEW_DAO_SYMBOL_0,
        DAO_RENAME_SYMBOL_1,
        DAO_BRIDGED_2
    }

    //region ---------------------------------------- Read

    /// @notice Local DAOs storage (in form of a mapping)
    function getDAO(string calldata daoSymbol) external view returns (ITokenomics.DaoData memory);

    /// @notice Owner of the DAO
    function getDAOOwner(string calldata daoSymbol) external view returns (address);

    /// @notice True if a DAO with such symbol already exists
    function isDaoSymbolInUse(string calldata daoSymbol) external view returns (bool);

    /// @notice Generate list of tasks that should be performed on the current phase
    function tasks(string calldata daoSymbol) external view returns (Task[] memory);

    /// @notice Get OS settings
    function getSettings() external view returns (OsSettings memory);

    /// @notice Get OS chain-depended settings
    function getChainSettings() external view returns (OsChainSettings memory);

    /// @notice Governance proposals. Can be created only at initialChain of DAO.
    function proposal(bytes32 proposalId) external view returns (ITokenomics.Proposal memory);

    /// @notice Get number of proposals for the given DAO
    function proposalsLength(string calldata daoSymbol) external view returns (uint);

    /// @notice Governance proposals. Can be created only at initialChain of DAO.
    /// @param daoSymbol DAO symbol
    /// @param index Starting index
    /// @param count Number of proposal ids to return
    function proposalIds(string calldata daoSymbol, uint index, uint count) external view returns (bytes32[] memory);
    //endregion ---------------------------------------- Read

    //region ---------------------------------------- Write actions

    /// @notice Set OS settings
    /// @custom:restricted Restricted through access manager (only admin)
    function setSettings(OsSettings memory newSettings) external;

    /// @notice Set OS chain-depended settings
    /// @custom:restricted Restricted through access manager (only admin)
    function setChainSettings(OsChainSettings memory newSettings) external;

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
    ) external payable;

    /// @notice Quote cost to create DAO
    /// @param daoSymbol Symbol of new DAO
    /// @return Cost in native currency to create the DAO using {createDAO(daoSymbol)}
    function quoteCreateDAO(string calldata daoSymbol) external view returns (uint);

    /// @notice Add live compatible DAO
    /// @custom:restricted Restricted through access manager (only verifier)
    function addLiveDAO(ITokenomics.DaoData memory dao) external;

    /// @notice Change lifecycle phase of a DAO
    /// @custom:restricted Restricted through access manager
    function changePhase(string calldata daoSymbol) external;

    /// @notice Provide funding to the DAO, receive seed or tge tokens in return
    function fund(string calldata daoSymbol, uint amount) external;

    /// @notice Process voting results from governance
    /// @custom:restricted Restricted through access manager
    function receiveVotingResults(bytes32 proposalId, bool succeed) external;

    /// @notice Refund funding to the SEED/TGE token holders if funding round failed
    function refund(string calldata daoSymbol) external;

    /// @notice Refund funding to the given SEED/TGE token holders if funding round failed
    /// @custom:restricted Restricted through access manager (only admin)
    function refundFor(string calldata daoSymbol, address[] memory receivers) external;

    /// @notice Handle incoming cross-chain message
    /// @custom:restricted Restricted through access manager (only OS bridge can call this function)
    /// @param srcEid LayerZero source endpoint ID
    /// @param guid_ Unique message identifier
    /// @param message_ Message payload
    function onReceiveCrossChainMessage(uint32 srcEid, bytes32 guid_, bytes memory message_) external;

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
