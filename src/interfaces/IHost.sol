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

    error AlreadyAnnounced();
    error SameVersion();
    error NoNewVersion();
    error UpgradeTimerIsNotOver(uint TimerTimestamp);

    event DaoCreated(string name, string daoSymbol, uint daoUid);

    event OsSettingsUpdated(IHost.HostSettings st);
    event OsChainSettingsUpdated(IHost.HostChainSettings st);
    event DaoImagesUpdated(string daoSymbol, ITokenomics.DaoImages images);
    event DaoSocialsUpdated(string daoSymbol, string[] socials);

    event Proposal(uint daoUid, ITokenomics.DAOAction action, bytes32 proposalId, bytes32 payloadHash, bytes payload);

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

    // todo replace daoSymbol by uid in events

    event DaoFundingUpdated(uint daoUid, ITokenomics.Funding funding);
    event DaoVestingUpdated(uint daoUid, ITokenomics.Vesting[] vestings);
    event DaoNamingUpdated(uint daoUid, ITokenomics.DaoNames daoNames);
    event DaoParametersUpdated(uint daoUid, ITokenomics.DaoParameters daoParameters);
    event DaoChainSettingsUpdated(uint daoUid, ITokenomics.DaoChainSettings chainSettings);
    event DaoPhaseChanged(uint daoUid, ITokenomics.LifecyclePhase newPhase);
    event DaoFunded(uint daoUid, address funder, uint amount, uint8 fundingType);
    event DaoRefunded(uint daoUid, address funder, address asset, uint amount, uint8 fundingType);
    event OnRegisterDaoSymbol(string daoSymbol, uint32 srcEid, bytes32 guid_);
    event OnRenameDaoSymbol(string oldSymbol, string newSymbol, uint32 srcEid, bytes32 guid_);
    event SaltUpdated(uint daoUid, uint16[] contractIndices, bytes32[] saltValues);
    event ProcessUnitRevenue(uint daoUid, string daoSymbol, string unitId, uint amount);
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

        /// @notice Add bridged version of the unit to another chain
        SET_BRIDGED_UNIT_2,

        /// @notice Remove bridged version of the unit from another chain
        REMOVE_BRIDGED_UNIT_3,

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

    //region ---------------------------------------- Read

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
    /// @return Salt value used in CREATE2
    function salt(string calldata daoSymbol, uint16 contractIndex) external view returns (bytes32);

    /// @notice Get implementation address for the given contract kind
    /// @param kind See IHost.ContractKinds
    function contractImplementation(uint kind) external view returns (address);

    /// @notice Quote gas cost to process voting results from governance
    /// @param proposalId Proposal unique id
    /// @param succeed True if proposal is approved
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if proposal was rejected.
    function quoteReceiveVotingResults(
        bytes32 proposalId,
        bool succeed,
        bytes memory payload
    ) external view returns (uint);

    /// @notice Get bridged action status by its hash
    /// @return applied True if the action was already applied on this chain
    /// @return actionKind Kind of the action, see IHost.BridgedActions
    /// @return daoUid UID of the DAO the action is applied to
    function getBridgedAction(
        bytes32 proposalId,
        bytes memory payload
    ) external view returns (bool applied, uint16 actionKind, uint daoUid);

    /// @notice Host version in CalVer scheme: YY.MM.MINOR-tag. Updates on core contract upgrades.
    function hostVersion() external view returns (string memory);

    /// @notice Get pending platform upgrade data
    function pendingPlatformUpgrade()
        external
        view
        returns (string memory newVersion, address[] memory proxies, address[] memory newImplementations);
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
    function receiveVotingResults(bytes32 proposalId, bool succeed, bytes memory payload) external payable;

    /// @notice Approve/reject proposal. This function is called by backed only for proposals that require validation.
    /// @param proposalId Proposal unique id
    /// @param valid True if proposal is approved, false if the proposal is rejected
    /// @param payload Data of the proposal. It's hash should be equal to the one stored in the proposal.
    /// Can be 0 if the proposal requires voting or is rejected.
    function validateProposal(bytes32 proposalId, bool valid, bytes memory payload) external;

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
    function updateSalts(string calldata daoSymbol, uint16[] memory contractIndices, bytes32[] memory salt_) external;

    /// @notice Create proposal to update bridged DAO version of the DAO on other {chains}
    /// @param daoSymbol DAO symbol
    /// @param actionKind Kind of action to perform on the bridged DAO, see BridgedActions enum
    /// @param dstEids LayerZero endpoint IDs of the chains with bridged DAO
    /// @param actionPayloads Payload of the action to perform on the bridged DAO on proper {chain}
    function createBridgedAction(
        string calldata daoSymbol,
        uint16 actionKind,
        uint32[] calldata dstEids,
        bytes[] calldata actionPayloads
    ) external;

    /// @notice Apply bridged action on the current chain. The action is approved by {proposalId} on the initial chain.
    /// @param proposalId Proposal unique id
    /// @param actionPayload Payload with action details.
    /// Its hash should be already registered on this chain through cross-chain message.
    function applyBridgedAction(bytes32 proposalId, bytes calldata actionPayload) external;
    //endregion ---------------------------------------- Update actions

    //region ---------------------------------------- Update host platform
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

    //endregion ---------------------------------------- Update host platform
}
