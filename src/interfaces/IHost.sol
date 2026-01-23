// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IDAOData} from "./IDAOData.sol";

/// @notice Allow to create DAO and update its state according to life cycle
interface IHost {
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
    error NotImplemented();
    error YouAreNotOwnerOf(string daoSymbol);
    error IncorrectDao();
    error ZeroBalance();
    error NotRefundPhase();
    error UnsupportedStructVersion();
    error IncorrectConfiguration();
    error UnitNotFound();
    error IncorrectArrayLengths();
    error TooHighContractIndex(uint16 index);
    error SaltAlreadyUsed(bytes32 salt);
    error UnitAlreadyRegistered();
    error IncorrectProposalPayload();
    error InstantExecuteNotAllowed();

    event DaoCreated(string name, string daoSymbol, uint daoUid);

    event OsSettingsUpdated(IHost.HostSettings st);
    event OsChainSettingsUpdated(IHost.HostChainSettings st);
    event DaoImagesUpdated(string daoSymbol, ITokenomics.DaoImages images);
    event DaoSocialsUpdated(string daoSymbol, string[] socials);

    event Proposal(
        uint daoUid,
        ITokenomics.DAOAction action,
        bytes32 proposalId,
        bytes32 payloadHash,
        bytes payload
    );

    /// @notice Units are updated via proposal or instantly
    event ProposalToUpdateDaoUnits(
        bytes32 proposalUid, uint daoUid, IDAOData.UnitDataInput[] units, IDAOData.UnitMetaData[] metaData
    );

    /// @notice Unit is inserted or updated
    /// @param proposalUid Zero if updated instantly
    event DaoUnitUpdatedByProposal(uint daoUid, string unitId, bytes32 proposalUid);

    event DaoUnitUpdatedInstantly(uint daoUid, string unitId, IDAOData.UnitMetaData metaData);

    /// @notice Unit is deleted
    /// @param proposalUid Zero if updated instantly
    event DaoUnitDeleted(uint daoUid, string unitId, bytes32 proposalUid);

    event DaoFundingUpdated(string daoSymbol, ITokenomics.Funding funding);
    event DaoVestingUpdated(string daoSymbol, ITokenomics.Vesting[] vestings);
    event DaoNamingUpdated(string daoSymbol, ITokenomics.DaoNames daoNames);
    event DaoParametersUpdated(string daoSymbol, ITokenomics.DaoParameters daoParameters);
    event DaoPhaseChanged(string daoSymbol, ITokenomics.LifecyclePhase newPhase);
    event DaoFunded(string daoSymbol, address funder, uint amount, uint8 fundingType);
    event DaoRefunded(string daoSymbol, address funder, address asset, uint amount, uint8 fundingType);
    event OnRegisterDaoSymbol(string daoSymbol, uint32 srcEid, bytes32 guid_);
    event OnRenameDaoSymbol(string oldSymbol, string newSymbol, uint32 srcEid, bytes32 guid_);
    event SaltUpdated(string daoSymbol, uint16[] contractIndices, bytes32[] saltValues, uint chain_);
    event ProcessUnitRevenue(uint daoUid, string daoSymbol, string unitId, uint amount);

    error NotEnoughNativeProvided(uint requiredValue);

    /// @notice DAO-setting common for all chains
    struct HostSettings {
        /// @notice Price of adding/creating DAO in exchange asset
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
    struct HostChainSettings {
        /// @notice The address of the asset used to fund the DAO.
        address exchangeAsset;

        /// @notice Address of the Host-bridge contract on the current chain
        address hostBridge;
    }

    struct Task {
        string name;
    }

    /// @notice Payload for Host initialization
    struct HostInitPayload {
        /// @notice DAO symbols registered on other chains
        string[] usedSymbols;

        /// @notice Symbol of host DAO. Empty if this is a first DAO on the first host
        string daoHostSymbol;

        /// @notice UID of host DAO. Zero if this is a first DAO on the first host
        uint daoHostUid;
    }

    /// @notice Kinds of cross-chain messages
    enum CrossChainMessages {
        /// @notice New DAO with given symbol is created on another chain
        NEW_DAO_SYMBOL_0,

        /// @notice DAO symbol was changed
        DAO_RENAME_SYMBOL_1,

        /// @notice DAO is bridged to another chain
        DAO_BRIDGED_2,

        /// @notice todo Unit is bridged to another chain
        UNIT_BRIDGED_3,

        /// @notice todo Life phase of the bridged DAO is changed to LIFE_CLIFF
        SET_LIVE_CLIFF_4,

        /// @notice todo DAO parameters are updated
        UPDATE_SEGMENT2_5,

        /// @notice todo DAO chains settings are updated
        UPDATE_SALTS_6
    }

    /// @notice All contracts deployed through HostProxyFactoryLib.deployContract
    enum ContractKinds {
        UNKNOWN_0,
        /// @notice SEED token
        SEED_TOKEN_1,
        /// @notice TGE token
        TGE_TOKEN_2
    }

    /// @notice Actions that can be performed on the bridged DAO on another chain (with pre-voting)
    enum BridgedActions {
        UNKNOWN_0,

        /// @notice Deploy bridged version of the DAO on another chain
        DAO_BRIDGED_1,

        /// @notice Add bridged version of the unit to another chain
        SET_BRIDGED_UNIT_2,

        /// @notice Remove bridged version of the unit from another chain
        REMOVE_BRIDGED_UNIT_3,

        /// @notice Update DAO parameters on another chain
        SET_DAO_PARAMS_4,

        /// @notice Set salt values for bridged contracts on another chain
        SET_SALTS_5
    }

    //region ---------------------------------------- Read

    // todo isSaltReserved

    /// @notice Local DAOs storage (in form of a mapping)
    function getDAO(string calldata daoSymbol) external view returns (IDAOData.DaoData memory);

    /// @notice Owner of the DAO
    function getDAOOwner(string calldata daoSymbol) external view returns (address);

    /// @notice Get UID of the Host DAO
    function getHostDaoUid() external view returns (uint);

    /// @notice True if a DAO with such symbol already exists
    function isDaoSymbolInUse(string calldata daoSymbol) external view returns (bool);

    /// @notice Generate list of tasks that should be performed on the current phase
    function tasks(string calldata daoSymbol) external view returns (Task[] memory);

    /// @notice Get OS settings
    function getSettings() external view returns (HostSettings memory);

    /// @notice Get OS chain-depended settings
    function getChainSettings() external view returns (HostChainSettings memory);

    /// @notice Governance proposals. Can be created only at initialChain of DAO.
    function proposal(bytes32 proposalId) external view returns (ITokenomics.Proposal memory);

    /// @notice Get number of proposals for the given DAO
    function proposalsLength(string calldata daoSymbol) external view returns (uint);

    /// @notice Governance proposals. Can be created only at initialChain of DAO.
    /// @param daoSymbol DAO symbol
    /// @param index Starting index
    /// @param count Number of proposal ids to return
    function proposalIds(string calldata daoSymbol, uint index, uint count) external view returns (bytes32[] memory);

    /// @notice Get balance belonging to the given unit
    function unitBalance(string calldata daoSymbol, string calldata unitUid) external view returns (uint);

    /// @notice Get salt to create contract with given index
    /// @param daoSymbol DAO symbol
    /// @param contractIndex Contract index, for exact values see ITokenomicsAddons.ContractIndices
    /// @param chainId Chain ID where the contract will be deployed. Use 0 for current chain
    /// @return Salt value used in CREATE2
    function salt(string calldata daoSymbol, uint16 contractIndex, uint chainId) external view returns (bytes32);

    /// @notice Get implementation address for the given contract kind
    /// @param kind See IHost.ContractKinds
    function contractImplementation(uint kind) external view returns (address);
    //endregion ---------------------------------------- Read

    //region ---------------------------------------- Write actions

    /// @notice Set OS settings
    /// @custom:restricted Restricted through access manager (only admin)
    function setSettings(HostSettings memory newSettings) external;

    /// @notice Set OS chain-depended settings
    /// @custom:restricted Restricted through access manager (only admin)
    function setChainSettings(HostChainSettings memory newSettings) external;

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
    function addLiveDAO(IDAOData.DaoDataInput calldata dao) external;

    /// @notice Change lifecycle phase of a DAO
    /// @custom:restricted Restricted through access manager
    function changePhase(string calldata daoSymbol) external;

    /// @notice Provide funding to the DAO, receive seed or tge tokens in return
    function fund(string calldata daoSymbol, uint amount) external;

    /// @notice Process voting results from governance
    /// @custom:restricted Restricted through access manager
    /// @param proposalId Proposal unique id
    /// @param succeed True if proposal is approved
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if proposal was rejected.
    function receiveVotingResults(bytes32 proposalId, bool succeed, bytes memory payload) external;

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

    /// @notice Process revenue generated by the unit.
    /// @param daoSymbol DAO symbol
    /// @param unitId Unit identifier
    /// @param amount Amount of revenue generated by the unit. This amount will be taken from the sender.
    function processUnitRevenue(string calldata daoSymbol, string memory unitId, uint amount) external;

    /// @notice Set implementation address for the contract of the given kind
    /// @param kind See IHost.ContractKinds
    function setContractImplementation(uint kind, address implementation) external;

    /// @notice Deploy new proxy contract
    /// @param salt_ Salt for create2 deployment
    /// @param logic Address of logic contract
    /// @param payload Initialization payload to pass to IHosted.initialize.
    /// Payload is created using abi.encode() and decoded using abi.decode(). Set of params depend on logic contract.
    /// @return proxy Address of deployed proxy contract
    function deployProxy(bytes32 salt_, address logic, bytes memory payload) external returns (address proxy);
    //endregion ---------------------------------------- Write actions

    //region ---------------------------------------- Update actions

    /// @notice Update/create proposal to update implementations of the DAO contracts
    function updateImages(string calldata daoSymbol, ITokenomics.DaoImages calldata images) external;

    /// @notice Update/create proposal to update list of socials of the DAO
    function updateSocials(string calldata daoSymbol, string[] calldata socials) external;

    /// @notice Update list of units/create a proposal to update list of units of the DAO
    /// @param daoSymbol DAO symbol
    /// @param units Units data to be stored on-chain
    /// @param metadata Units metadata to be emitted and used off-chain only
    function updateUnits(
        string calldata daoSymbol,
        IDAOData.UnitDataInput[] calldata units,
        IDAOData.UnitMetaData[] calldata metadata
    ) external;

    /// @notice Update/create proposal to update funding rounds of the DAO
    function updateFunding(string calldata daoSymbol, ITokenomics.Funding calldata funding) external;

    /// @notice Update/create proposal to update vesting schedules of the DAO
    function updateVesting(string calldata daoSymbol, ITokenomics.Vesting[] calldata vestings) external;

    /// @notice Update/create proposal to update DAO naming (name and symbol)
    function updateNaming(string calldata daoSymbol, ITokenomics.DaoNames calldata daoNames_) external payable;

    /// @notice Update/create proposal to update on-chain DAO parameters
    function updateDaoParameters(string calldata daoSymbol, ITokenomics.DaoParameters calldata daoParameters_) external;

    /// @notice Set salt to create contracts with given indices
    /// @param contractIndices Contract indices, for exact values see ITokenomicsAddons.ContractIndices
    /// @param salt_ Salt values for the corresponded contracts. The salt is used in CREATE2
    /// @param chainId Chain ID where the contract will be deployed. Use 0 for current chain
    function updateSalts(
        string calldata daoSymbol,
        uint16[] memory contractIndices,
        bytes32[] memory salt_,
        uint chainId
    ) external;

    /// @notice Create proposal to update bridged DAO version of the DAO on other chain
    /// @param daoSymbol DAO symbol
    /// @param targetChainId Target chain ID where the bridged DAO is located
    /// @param actionKind Kind of action to perform on the bridged DAO, see BridgedActions enum
    /// @param actionPayload Payload of the action to perform on the bridged DAO
    function updateBridgedDao(
        string calldata daoSymbol,
        uint targetChainId,
        uint16 actionKind,
        bytes calldata actionPayload
    ) external;

    //endregion ---------------------------------------- Update actions
}
