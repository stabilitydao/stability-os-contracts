// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IDAOData} from "./IDAOData.sol";
import {IBridgedActions} from "../interfaces/IBridgedActions.sol";

/// @notice Allow to create DAO and update its state according to life cycle
interface IHost {
    error NameLength(uint length);
    error SymbolLength(uint length);
    error SymbolNotUnique(string symbol);
    error UpperCaseRequired(string symbol);
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
    error YouAreNotOwnerOf(string symbol);
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
    error ProposalNotValidated();
    error ValidationNotRequired();
    error AlreadyValidated();
    error UnknownBridgedActionHash();
    error UnknownBridgedActionKind();
    error VotingNotRequired();
    error BridgedActionAlreadyApplied();
    error UnitsRequired();
    error WrongAction();
    error AlreadyBridged();
    error IncorrectInputData();
    error InvalidEmitDataForAction();
    error UnknownRestrictedAction();
    error NotInitialChain();
    error InvalidActivityCombination();
    error ZeroActivityNotAllowed();
    error InvalidFundingPeriod();
    error InvalidFundingRaise();
    error InvalidFundingArray();
    error IncorrectVestingPeriod();
    error TooLowValue();
    error ZeroValueNotAllowed();
    error TotalAllocationTooHigh();
    error VestingNotAllowed();
    error IncorrectVestingStart();
    error TooLateToUpdateTotalSupply();
    error NotEnoughUserPower();
    error TooHighValue();

    error AlreadyAnnounced();
    error SameVersion();
    error NoNewVersion();
    error UpgradeTimerIsNotOver(uint TimerTimestamp);
    error LogicNotFound(uint kind);

    event DaoCreated(string name, string symbol, uint daoUid);
    event OsSettingsUpdated(IHost.HostSettings st);
    event OsChainSettingsUpdated(IHost.HostChainSettings st);
    event DaoImagesUpdated(string symbol, ITokenomics.DaoImages images);
    event DaoSocialsUpdated(string symbol, string[] socials);
    event Proposal(uint daoUid, ITokenomics.DAOAction action, bytes32 proposalId, bytes32 payloadHash, bytes payload);

    /// @notice Units are updated via proposal or instantly
    event ProposalToUpdateDaoUnits(
        bytes32 proposalUid, uint daoUid, IDAOData.UnitDataInput[] units, IDAOData.UnitEmitData[] emitData
    );

    /// @notice Unit is inserted or updated
    /// @param proposalUid Zero if updated instantly
    event DaoUnitUpdatedByProposal(uint daoUid, string unitId, bytes32 proposalUid);

    event DaoUnitUpdatedInstantly(uint daoUid, string unitId, IDAOData.UnitEmitData metaData);

    /// @notice Unit is deleted
    /// @param proposalUid Zero if updated instantly
    event DaoUnitDeleted(uint daoUid, string unitId, bytes32 proposalUid);

    event DaoFundingUpdated(uint daoUid, ITokenomics.Funding funding);
    event DaoVestingUpdated(uint daoUid, ITokenomics.Vesting[] vestings);
    event DaoNamingUpdated(uint daoUid, ITokenomics.DaoNames daoNames);
    event DaoParametersUpdated(uint daoUid, ITokenomics.DaoParameters daoParameters);
    event DaoChainSettingsUpdated(uint daoUid, ITokenomics.DaoChainSettings chainSettings);
    event DaoPhaseChanged(uint daoUid, ITokenomics.LifecyclePhase newPhase);
    event DaoFunded(uint daoUid, address funder, uint amount, uint8 fundingType);
    event DaoRefunded(uint daoUid, address funder, address asset, uint amount, address fundingToken);
    event OnRegisterDaoSymbol(string symbol, uint32 srcEid, bytes32 guid_);
    event OnRenameDaoSymbol(string oldSymbol, string newSymbol, uint32 srcEid, bytes32 guid_);
    event SaltUpdated(uint daoUid, uint16[] contractIndices, bytes32[] saltValues);
    event ProcessUnitRevenue(uint daoUid, string symbol, string unitId, uint amount);
    event OnBridgedDaoAction(bytes32 actionHash, uint16 actionKind, uint32 srcEid, bytes32 guid_);

    error NotEnoughNativeProvided(uint requiredValue);
    event ProposalValidated(bytes32 proposalId, bool valid);
    event BridgedActionSent(uint daoUid, uint16 actionKind, uint32 dstEid, bytes32 hash);

    event BridgeDao(uint daoUid, IBridgedActions.BridgeDaoParams params, string[] unitIds);

    event HostVersion(string version);
    event UpgradeAnnounce(
        string oldVersion, string newVersion, address[] proxies, address[] newImplementations, uint timelock
    );
    event CancelUpgrade(string oldVersion, string newVersion);
    event ProxyUpgraded(
        address indexed proxy, address implementation, string oldContractVersion, string newContractVersion
    );

    event NewContractImplementation(uint kind, address seedToken);
    event ProxyDeployed(address proxy, address implementation, bytes payload);
    event ContractDeployed(address proxy, uint kind, bytes payload);

    event VestingDescription(uint daoUid, string vestingName, string description);
    event HostInitialized(string daoHostSymbol, uint daoHostUid, string hostVersion, string[] usedSymbols);

    event BridgedUnitsUpdated(uint daoUid, string[] unitIds);

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

        /// @notice min VE period in days
        uint minVePeriod;
        /// @notice max VE period in days
        uint maxVePeriod;

        uint minPvPFee;
        uint maxPvPFee;

        /// @notice Min amount allowed to fund the DAO in exchange asset.
        uint minFunding;

        /// @notice Minimal funding duration, seconds
        uint minFundingDuration;
        /// @notice Max funding duration, seconds
        uint maxFundingDuration;

        /// @notice Minimum allowed funding amount to raise
        uint minFundingRaise;

        /// @notice Maximum allowed funding amount to raise.
        uint maxFundingRaise;

        /// @notice Min length of a vesting name
        uint minVestingNameLen;

        /// @notice Max length of a vesting name
        uint maxVestingNameLen;

        /// @notice Min allowed interval (seconds) between vesting.start and tge.claim
        uint minCliff;

        /// @notice Min allowed duration of inception phase, seconds. Phase SEED can be activated not later than SEED.start + maxSeedStartDelay
        uint minInceptionDuration;
    }

    /// @notice Chain-dependent data of the DAO
    struct HostChainSettings {
        /// @notice The address of the asset used to fund the DAO.
        address exchangeAsset;

        /// @notice Address of the Host-bridge contract on the current chain
        address hostBridge;

        /// @notice Timelock duration for host platform upgrades, sec
        uint timelock;

        /// @notice Data reader provides access to any DAO-related complex data in human-readable format
        address dataReader;
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

        /// @notice Initial version of host platform
        string hostVersion;
    }

    /// @notice Kinds of cross-chain messages
    enum CrossChainMessages {
        /// @notice New DAO with given symbol is created on another chain
        NEW_DAO_SYMBOL_0,

        /// @notice DAO symbol was changed
        DAO_RENAME_SYMBOL_1,

        /// @notice Send action hash to another chain
        DAO_BRIDGED_ACTION_HASH_2
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

        /// @notice Deploy bridged version of the DAO on another chain without deployments (stage before LIVE)
        BRIDGE_DAO_1,

        /// @notice Set list of units bridged to another chain (add/remove/edit units)
        SET_BRIDGED_UNITS_2,

        /// @dev Currently not used, we can use it for any new action
        RESERVED_3,

        /// @notice Update DAO parameters on another chain
        SET_DAO_PARAMS_4,

        /// @notice Set salt values for bridged contracts on another chain
        SET_SALTS_5,

        /// @notice Update DAO chain-related params on another chain
        UPDATE_CHAIN_SETTINGS_6,

        /// @notice Deploy bridged version of the DAO on another chain with deployments (stage = LIVE)
        BRIDGE_DAO_WITH_DEPLOYMENTS_7,

        /// @notice Deploy bridged version of token (DAO was bridged before)
        DEPLOYMENTS_8
    }

    /// @notice Data items that can be requested from DataReader
    enum DataReaderItem {
        /// @notice Full DAO data
        DAO_DATA_0,
        /// @notice Full proposal data
        PROPOSAL_1,
        DAO_NAME_2,
        DAO_SYMBOL_3
    }

    /// @notice Rarely used restricted actions, see {updateByAdmin}
    enum AdminUpdateActions {
        /// @notice Add live compatible DAO
        /// payload is encoded DaoDataInput, see HostEncodingLib.encodeDaoDataInput
        ADD_LIVE_DAO_0
    }

    /// @notice Token kind for getTokenName and getTokenSymbol
    enum NamingTokenKind {
        SEED_0,
        TGE_1,
        TOKEN_2,
        XTOKEN_3,
        DAO_4
    }

    /// @notice Validation method for proposals: either receiveVotingResults or validateProposal
    enum ValidationMethod {
        /// @notice receiveVotingResults(succeeded=true)
        VOTING_0,
        /// @notice validateProposal(valid=true)
        VALIDATION_1
    }

    //region ---------------------------------------- View

    /// @notice Data reader provides access to any DAO-related complex data in human-readable format
    function dataReader() external view returns (address);

    /// @notice Data rider gets all data through this function
    /// @param itemIndex Index of the item to get, see IHost.DataReaderItem
    /// @param input Encoded input data for the item
    /// @param version Required version of the output data
    /// @return Encoded output data for the item
    function getBinaryData(uint itemIndex, bytes memory input, uint16 version) external view returns (bytes memory);

    /// @notice Owner of the DAO
    function ownerDAO(string calldata symbol) external view returns (address);

    /// @notice Get UID of the Host DAO
    function hostDaoUid() external view returns (uint);

    /// @notice True if a DAO with such symbol already exists
    function isDaoSymbolInUse(string calldata symbol) external view returns (bool);

    /// @notice Generate list of tasks that should be performed on the current phase
    function tasks(string calldata symbol) external view returns (Task[] memory);

    /// @notice Get OS settings
    function getSettings() external view returns (HostSettings memory);

    /// @notice Get OS chain-depended settings
    function getChainSettings() external view returns (HostChainSettings memory);

    /// @notice Get number of proposals for the given DAO
    function proposalsLength(string calldata symbol) external view returns (uint);

    /// @notice Governance proposals. Can be created only at initialChain of DAO.
    /// @param symbol DAO symbol
    /// @param index Starting index
    /// @param count Number of proposal ids to return
    function proposalIds(string calldata symbol, uint index, uint count) external view returns (bytes32[] memory);

    /// @notice Get balance belonging to the given unit
    function unitBalance(string calldata symbol, string calldata unitUid) external view returns (uint);

    /// @notice Get salt to create contract with given index
    /// @param symbol DAO symbol
    /// @param contractIndex Contract index, for exact values see ITokenomics.ContractIndices
    /// @return Salt value used in CREATE2
    function salt(string calldata symbol, uint16 contractIndex) external view returns (bytes32);

    /// @notice Get implementation address for the given contract kind
    /// @param kind See IHost.ContractKinds
    function contractImplementation(uint kind) external view returns (address);

    /// @notice Quote cost to create DAO
    /// @param symbol Symbol of new DAO
    /// @return Cost in native currency to create the DAO using {createDAO(symbol)}
    function quoteCreateDAO(string calldata symbol) external view returns (uint);

    /// @notice Quote gas cost to perform action suggested by proposal
    /// The action can be performed by calling either {receiveVotingResults(succeeded=true)} or {validateProposal(valid=true)}
    /// @param proposalId Proposal unique id
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if proposal was rejected.
    /// @param method Kind of operation that you are going to perform: 0 - receiveVotingResults, 1 - validateProposal
    /// @return Estimated fee (in native token) to process the voting results
    function quoteProposalAction(
        bytes32 proposalId,
        bytes memory payload,
        ValidationMethod method
    ) external view returns (uint);

    /// @notice Get bridged action status by its hash
    /// @return applied True if the action was already applied on this chain
    /// @return actionKind Kind of the action, see IHost.BridgedActions
    /// @return daoUid UID of the DAO the action is applied to
    function bridgedAction(
        bytes32 proposalId,
        bytes memory payload
    ) external view returns (bool applied, uint16 actionKind, uint daoUid);

    /// @notice Host version in CalVer scheme: YY.MM.MINOR-tag. Updates on core contract upgrades.
    function hostVersion() external view returns (string memory);

    /// @notice Get pending platform upgrade data
    function pendingUpgrade()
        external
        view
        returns (string memory newVersion, address[] memory proxies, address[] memory newImplementations);
    //endregion ---------------------------------------- View

    //region ---------------------------------------- User write actions

    /// @notice Create new DAO
    /// @param name Name of new DAO (any name is allowed)
    /// @param symbol Symbol of new DAO (should be unique across all DAOs, it can be changed later)
    /// @param activity List of activities of the DAO
    /// @param params On-chain DAO parameters
    /// @param funding Initial funding rounds of the DAO
    function createDAO(
        string calldata name,
        string calldata symbol,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) external payable;

    /// @notice Update/create proposal to update DAO values
    /// @param symbol DAO symbol
    /// @param action Action kind, see ITokenomics.DAOAction
    /// @param payload Data of the action. Use HostCodec.encode to create it. Its format depend on the action kind.
    /// This data should be passed together with {proposalId} to {receiveVotingResults} after voting
    /// @param emitData Additional data that is not stored on-chain, but emitted in the event and can be used off-chain
    function updateDAO(string calldata symbol, uint16 action, bytes memory payload, bytes memory emitData) external;

    /// @notice Create proposal to update bridged DAO version of the DAO on other {chains}
    /// @param symbol DAO symbol
    /// @param actionKind Kind of action to perform on the bridged DAO, see BridgedActions enum
    /// @param dstEids LayerZero endpoint IDs of the chains with bridged DAO
    /// @param actionPayloads Payload of the action to perform on the bridged DAO on proper {chain}
    function createBridgedAction(
        string calldata symbol,
        uint16 actionKind,
        uint32[] calldata dstEids,
        bytes[] calldata actionPayloads
    ) external;

    /// @notice Apply bridged action on the current chain. The action is approved by {proposalId} on the initial chain.
    /// @param proposalId Proposal unique id
    /// @param actionPayload Payload with action details.
    /// Its hash should be already registered on this chain through cross-chain message.
    function applyBridgedAction(bytes32 proposalId, bytes calldata actionPayload) external;

    /// @notice Change lifecycle phase of a DAO
    function changePhase(string calldata symbol) external;

    /// @notice Provide funding to the DAO, receive seed or tge tokens in return
    function fund(string calldata symbol, uint amount) external;

    /// @notice Refund funding to the SEED/TGE token holders if funding round failed
    function refund(string calldata symbol) external;

    /// @notice Process revenue generated by the unit.
    /// @param symbol DAO symbol
    /// @param unitId Unit identifier
    /// @param amount Amount of revenue generated by the unit. This amount will be taken from the sender.
    function processUnitRevenue(string calldata symbol, string memory unitId, uint amount) external;

    //endregion ---------------------------------------- User write actions

    //region ---------------------------------------- Restricted write actions

    /// @notice Process voting results from governance
    /// @custom:restricted Restricted through access manager
    /// @param proposalId Proposal unique id
    /// @param succeed True if proposal is approved
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if proposal was rejected.
    function receiveVotingResults(bytes32 proposalId, bool succeed, bytes memory payload) external payable;

    /// @notice Approve/reject proposal. This function is called by backed only for proposals that require validation.
    /// @custom:restricted Restricted through access manager
    /// @param proposalId Proposal unique id
    /// @param valid True if proposal is approved, false if the proposal is rejected
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if the proposal requires voting or is rejected.
    function validateProposal(bytes32 proposalId, bool valid, bytes memory payload) external;

    /// @notice Announce upgrade of host proxies implementations
    /// @custom:restricted Restricted through access manager (only governance or multisig)
    /// @param newVersion New host version. Version must be changed when upgrading.
    /// @param proxies Addresses of core contract proxies
    /// @param newImplementations New implementation for proxy. Index of proxy same as in previous array.
    function announceUpgrade(
        string memory newVersion,
        address[] memory proxies,
        address[] memory newImplementations
    ) external;

    /// @notice Apply pending upgrade
    /// @custom:restricted Restricted through access manager (only operator)
    function upgrade() external;

    /// @notice Cancel pending upgrade
    /// @custom:restricted Restricted through access manager (only operator)
    function cancelUpgrade() external;

    /// @notice Any rarely used restricted action like addLiveDAO
    /// @custom:restricted Restricted through access manager (only verifier)
    /// @param actionIndex Index of the action to perform
    /// @param payload Encoded payload of the action. Its format depend on the action kind. See IHost.RestrictedUpdates
    function updateByAdmin(AdminUpdateActions actionIndex, bytes memory payload) external;

    /// @notice Refund funding to the given SEED/TGE token holders if funding round failed
    /// @custom:restricted Restricted through access manager (only admin)
    /// @param symbol DAO symbol
    /// @param users List of users to refund. Each user receives exchange asset in exchange on funding tokens as 1:1.
    /// Exact kind of funding token depends on the current phase of the DAO.
    function refundFor(string calldata symbol, address[] memory users) external;

    /// @notice Handle incoming cross-chain message
    /// @custom:restricted Restricted through access manager (only Host bridge can call this function)
    /// @param srcEid LayerZero source endpoint ID
    /// @param guid_ Unique message identifier
    /// @param message_ Message payload
    function onReceiveCrossChainMessage(uint32 srcEid, bytes32 guid_, bytes memory message_) external;

    /// @notice Deploy new proxy contract
    /// @custom:restricted Restricted through access manager
    /// @param salt_ Salt for create2 deployment
    /// @param logic Address of logic contract
    /// @param payload Initialization payload to pass to IHosted.initialize.
    /// Payload is created using abi.encode() and decoded using abi.decode(). Set of params depend on logic contract.
    /// @return proxy Address of deployed proxy contract
    function deployProxy(bytes32 salt_, address logic, bytes memory payload) external returns (address proxy);

    /// @notice Set Host settings
    /// @custom:restricted Restricted through access manager (only admin)
    function setSettings(HostSettings memory newSettings) external;

    /// @notice Set Host chain-depended settings
    /// @custom:restricted Restricted through access manager (only admin)
    function setChainSettings(HostChainSettings memory newSettings) external;

    /// @notice Set implementation address for the contract of the given kind
    /// @custom:restricted Restricted through access manager
    /// @param kind See IHost.ContractKinds
    function setContractImplementation(uint kind, address implementation) external;

    //endregion ---------------------------------------- Restricted write actions
}
