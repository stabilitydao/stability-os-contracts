// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {HostActionsLib} from "./libs/HostActionsLib.sol";
import {HostRestrictedActionsLib} from "./libs/HostRestrictedActionsLib.sol";
import {HostCrossChainLib} from "./libs/HostCrossChainLib.sol";
import {HostFundingLib} from "./libs/HostFundingLib.sol";
import {HostProposalLib} from "./libs/HostProposalLib.sol";
import {HostBridgeLib} from "./libs/HostBridgeLib.sol";
import {HostProxyLib} from "./libs/HostProxyLib.sol";
import {HostViewLib} from "./libs/HostViewLib.sol";
import {HostConfigLib} from "./libs/HostConfigLib.sol";
import {Hosted} from "./base/Hosted.sol";
import {IHosted} from "./interfaces/IHosted.sol";
import {IHost} from "./interfaces/IHost.sol";
import {IDAOData} from "./interfaces/IDAOData.sol";

/// @notice Allow to create DAO and update its state according to life cycle
/// DAO must manage properties itself via voting by executing Operating proposals.
contract Host is IHost, Hosted, ReentrancyGuardUpgradeable {
    /// @inheritdoc IHosted
    string public constant VERSION = "1.0.0";

    /// @notice Max number of tasks returned by `tasks` function
    uint internal constant MAX_COUNT_TASKS = 25;

    /// @inheritdoc IHosted
    function initialize(address authority_, bytes memory payload) public payable initializer {
        __Hosted_init(authority_);
        __ReentrancyGuard_init();

        // register all symbols registered on other chains
        IHost.HostInitPayload memory initPayload = abi.decode(payload, (IHost.HostInitPayload));
        HostActionsLib.initHost(initPayload);
    }

    //region -------------------------------------- View
    /// @inheritdoc IHost
    function dataReader() external view returns (address) {
        return HostConfigLib.getHostChainSettings().dataReader;
    }

    /// @inheritdoc IHost
    function getBinaryData(uint itemIndex, bytes memory input, uint16 version) external view returns (bytes memory) {
        return HostViewLib.getDataReaderItem(IHost.DataReaderItem(itemIndex), input, version);
    }

    /// @inheritdoc IHost
    function hostDaoUid() external view returns (uint) {
        return HostViewLib.getHostDaoUid();
    }

    /// @inheritdoc IHost
    function getSettings() external view returns (IHost.HostSettings memory) {
        return HostViewLib.getSettings();
    }

    /// @inheritdoc IHost
    function getChainSettings() external view returns (IHost.HostChainSettings memory) {
        return HostViewLib.getChainSettings();
    }

    /// @inheritdoc IHost
    function tasks(string calldata symbol) external view returns (IHost.Task[] memory) {
        return HostViewLib.tasks(symbol, MAX_COUNT_TASKS);
    }

    /// @inheritdoc IHost
    function ownerDAO(string calldata symbol) external view returns (address) {
        return HostViewLib.getDAOOwner(symbol);
    }

    /// @inheritdoc IHost
    function isDaoSymbolInUse(string calldata symbol) external view returns (bool) {
        return HostViewLib.isDaoSymbolInUse(symbol);
    }

    /// @inheritdoc IHost
    function proposalsLength(string calldata symbol) external view returns (uint) {
        return HostViewLib.proposalsLength(symbol);
    }

    /// @inheritdoc IHost
    function proposalIds(string calldata symbol, uint index, uint count) external view returns (bytes32[] memory) {
        return HostViewLib.proposalIds(symbol, index, count);
    }

    /// @inheritdoc IHost
    function quoteCreateDAO(string calldata symbol) external view returns (uint) {
        return HostCrossChainLib.quoteMessageToAllChains(
            IHost.CrossChainMessages.NEW_DAO_SYMBOL_0, HostCrossChainLib.packMessageNewDaoSymbol(symbol)
        );
    }

    /// @inheritdoc IHost
    function unitBalance(string calldata symbol, address asset, string calldata unitId) external view returns (uint) {
        return HostViewLib.unitBalance(symbol, asset, unitId);
    }

    /// @inheritdoc IHost
    function salt(string calldata symbol, uint16 contractIndex) external view returns (bytes32) {
        return HostViewLib.salt(symbol, contractIndex);
    }

    /// @inheritdoc IHost
    function contractImplementation(uint kind) external view returns (address) {
        return HostProxyLib.contractImplementation(kind);
    }

    /// @inheritdoc IHost
    function quoteProposalAction(
        bytes32 proposalId,
        bytes memory payload,
        IHost.ValidationMethod method
    ) external view returns (uint) {
        return HostProposalLib.quoteProposalAction(proposalId, payload, method);
    }

    /// @inheritdoc IHost
    function bridgedAction(
        bytes32 proposalId,
        bytes memory payload
    ) external view returns (bool applied, uint16 actionKind, uint daoUid) {
        return HostViewLib.getBridgedAction(HostBridgeLib._getHashProposalAction(proposalId, payload));
    }

    /// @inheritdoc IHost
    function hostVersion() external view returns (string memory) {
        return HostProxyLib.hostVersion();
    }

    /// @inheritdoc IHost
    function pendingUpgrade()
        external
        view
        returns (string memory newVersion, address[] memory proxies, address[] memory newImplementations)
    {
        return HostProxyLib.pendingUpgrade();
    }

    /// @inheritdoc IHost
    function isAssetWhitelisted(address asset_) external view returns (bool) {
        return HostViewLib.isAssetWhitelisted(asset_);
    }

    //endregion -------------------------------------- View

    //region -------------------------------------- Actions
    /// @inheritdoc IHost
    function createDAO(
        string calldata name,
        string calldata symbol,
        IDAOData.Activity[] memory activity,
        IDAOData.DaoParameters memory params,
        IDAOData.Funding[] memory funding
    ) external payable {
        // no restrictions, anybody can create a DAO
        HostActionsLib.createDAO(name, symbol, activity, params, funding);
    }

    /// @inheritdoc IHost
    function updateDAO(string calldata symbol, uint16 action, bytes memory payload, bytes memory emitData) external {
        HostProposalLib.updateDAO(symbol, action, payload, emitData);
    }

    /// @inheritdoc IHost
    function createBridgedAction(
        string calldata symbol,
        uint16 actionKind,
        uint32[] calldata dstEids,
        bytes[] calldata actionPayloads
    ) external {
        // restrictions are checked below
        HostProposalLib.updateBridgedDao(symbol, actionKind, dstEids, actionPayloads);
    }

    /// @inheritdoc IHost
    function applyBridgedAction(bytes32 proposalId, bytes calldata actionPayload) external {
        HostBridgeLib.applyBridgedAction(proposalId, actionPayload);
    }

    /// @inheritdoc IHost
    function changePhase(string calldata symbol) external {
        // no restrictions, anybody can call this

        HostActionsLib.changePhase(symbol, authority());
    }

    /// @inheritdoc IHost
    function fund(string calldata symbol, uint amount) external nonReentrant {
        // no restrictions, anybody can call this

        HostFundingLib.fund(symbol, amount);
    }

    /// @inheritdoc IHost
    function refund(string calldata symbol) external nonReentrant {
        HostFundingLib.refund(symbol);
    }

    /// @inheritdoc IHost
    function revenue(string calldata symbol, string memory unitId, address asset, uint amount) external nonReentrant {
        // todo no restrictions?
        HostActionsLib.processUnitRevenue(symbol, unitId, asset, amount);
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Restricted actions
    /// @inheritdoc IHost
    function receiveVotingResults(bytes32 proposalId, bool succeed, bytes memory payload) external payable restricted {
        HostProposalLib.receiveVotingResults(proposalId, succeed, payload);
    }

    /// @inheritdoc IHost
    function validateProposal(bytes32 proposalId, bool valid, bytes memory payload) external payable restricted {
        HostProposalLib.validateProposal(proposalId, valid, payload);
    }

    /// @inheritdoc IHost
    function announceUpgrade(
        string memory newVersion,
        address[] memory proxies,
        address[] memory newImplementations
    ) external restricted {
        HostProxyLib.announceUpgrade(newVersion, proxies, newImplementations);
    }

    /// @inheritdoc IHost
    function upgrade() external restricted {
        HostProxyLib.upgrade();
    }

    /// @inheritdoc IHost
    function cancelUpgrade() external restricted {
        HostProxyLib.cancelUpgrade();
    }

    /// @inheritdoc IHost
    function updateByAdmin(IHost.AdminUpdateActions actionIndex, bytes memory payload) external restricted {
        HostRestrictedActionsLib.updateByAdmin(actionIndex, payload);
    }

    /// @inheritdoc IHost
    function refundFor(string calldata symbol, address[] memory users) external restricted {
        HostFundingLib.refundFor(symbol, users);
    }

    /// @inheritdoc IHost
    function onReceiveCrossChainMessage(uint32 srcEid, bytes32 guid_, bytes memory message_) external restricted {
        HostCrossChainLib.onReceiveCrossChainMessage(srcEid, guid_, message_);
    }

    /// @inheritdoc IHost
    function deployProxy(
        bytes32 salt_,
        address logic,
        bytes memory payload
    ) external restricted returns (address proxy) {
        return HostProxyLib.deployProxy(salt_, logic, payload, authority());
    }

    /// @inheritdoc IHost
    function setSettings(IHost.HostSettings memory newSettings) external restricted {
        HostActionsLib.setSettings(newSettings);
    }

    /// @inheritdoc IHost
    function setChainSettings(IHost.HostChainSettings memory newSettings) external restricted {
        HostActionsLib.setChainSettings(newSettings);
    }

    /// @inheritdoc IHost
    function setContractImplementation(uint kind, address implementation) external restricted {
        HostProxyLib.setContractImplementation(kind, implementation);
    }

    /// @inheritdoc IHost
    function whitelistAssets(address[] memory assets_, bool whitelisted) external restricted {
        HostActionsLib.whitelistAsset(assets_, whitelisted);
    }

    //endregion -------------------------------------- Restricted actions
}
