// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "./interfaces/ITokenomics.sol";
import {IDAOData} from "./interfaces/IDAOData.sol";
import {IHost} from "./interfaces/IHost.sol";
import {HostActionsLib} from "./libs/HostActionsLib.sol";
import {HostProposalsLib} from "./libs/HostProposalsLib.sol";
import {HostFundingLib} from "./libs/HostFundingLib.sol";
import {HostCrossChainLib} from "./libs/HostCrossChainLib.sol";
import {HostViewLib} from "./libs/HostViewLib.sol";
import {Hosted} from "./base/Hosted.sol";
import {IHosted} from "./interfaces/IHosted.sol";
import {HostProxyFactoryLib} from "./libs/HostProxyFactoryLib.sol";
import {HostUpdateBridgedLib} from "./libs/HostUpdateBridgedLib.sol";
import {HostUpgradeProxyLib} from "./libs/HostUpgradeProxyLib.sol";

/// @notice Allow to create DAO and update its state according to life cycle
/// [META-ISSUE] DAO must manage properties itself via voting by executing Operating proposals.
contract Host is IHost, Hosted {
    /// @inheritdoc IHosted
    string public constant VERSION = "1.0.0";

    /// @notice Max number of tasks returned by `tasks` function
    uint internal constant MAX_COUNT_TASKS = 25;

    /// @inheritdoc IHosted
    function initialize(address authority_, bytes memory payload) public payable initializer {
        __Hosted_init(authority_);

        // register all symbols registered on other chains
        IHost.HostInitPayload memory initPayload = abi.decode(payload, (IHost.HostInitPayload));
        HostActionsLib.initHost(initPayload);
    }

    //region -------------------------------------- View
    /// @inheritdoc IHost
    function getDataReaderItem(IHost.DataReaderItem itemIndex, bytes memory input, uint version) external view returns (bytes memory) {
        return HostViewLib.getDataReaderItem(itemIndex, input, version);
    }

    /// @inheritdoc IHost
    function getDAO(string calldata symbol) external view returns (IDAOData.DaoData memory) {
        return HostViewLib.getDAO(symbol);
    }

    /// @inheritdoc IHost
    function getHostDaoUid() external view returns (uint) {
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
    function getDAOOwner(string calldata symbol) external view returns (address) {
        return HostViewLib.getDAOOwner(symbol);
    }

    /// @inheritdoc IHost
    function isDaoSymbolInUse(string calldata symbol) external view returns (bool) {
        return HostViewLib.isDaoSymbolInUse(symbol);
    }

    /// @inheritdoc IHost
    function proposal(bytes32 proposalId) external view returns (ITokenomics.Proposal memory) {
        return HostViewLib.proposal(proposalId);
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

    function unitBalance(string calldata symbol, string calldata unitId) external view returns (uint) {
        return HostViewLib.unitBalance(symbol, unitId);
    }

    function salt(string calldata symbol, uint16 contractIndex) external view returns (bytes32) {
        return HostViewLib.salt(symbol, contractIndex);
    }

    /// @inheritdoc IHost
    function contractImplementation(uint kind) external view returns (address) {
        return HostProxyFactoryLib.contractImplementation(kind);
    }

    /// @inheritdoc IHost
    function quoteReceiveVotingResults(
        bytes32 proposalId,
        bool succeed,
        bytes memory payload
    ) external view returns (uint) {
        return HostProposalsLib.quoteReceiveVotingResults(proposalId, succeed, payload);
    }

    /// @inheritdoc IHost
    function getBridgedAction(
        bytes32 proposalId,
        bytes memory payload
    ) external view returns (bool applied, uint16 actionKind, uint daoUid) {
        return HostViewLib.getBridgedAction(HostUpdateBridgedLib._getHashProposalAction(proposalId, payload));
    }

    /// @inheritdoc IHost
    function hostVersion() external view returns (string memory) {
        return HostUpgradeProxyLib.hostVersion();
    }

    /// @inheritdoc IHost
    function pendingUpgrade()
        external
        view
        returns (string memory newVersion, address[] memory proxies, address[] memory newImplementations)
    {
        return HostUpgradeProxyLib.pendingUpgrade();
    }

    //endregion -------------------------------------- View

    //region -------------------------------------- Actions
    /// @inheritdoc IHost
    function createDAO(
        string calldata name,
        string calldata symbol,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) external payable {
        // no restrictions, anybody can create a DAO
        HostActionsLib.createDAO(name, symbol, activity, params, funding);
    }

    /// @inheritdoc IHost
    function changePhase(string calldata symbol) external {
        // no restrictions, anybody can call this

        HostViewLib.changePhase(symbol, authority());
    }

    /// @inheritdoc IHost
    function fund(string calldata symbol, uint amount) external {
        // todo not reentrant
        // no restrictions, anybody can call this

        HostFundingLib.fund(symbol, amount);
    }

    /// @inheritdoc IHost
    function refund(string calldata symbol) external {
        // todo not reentrant
        HostFundingLib.refund(symbol);
    }

    /// @inheritdoc IHost
    function processUnitRevenue(string calldata symbol, string memory unitId, uint amount) external {
        // todo no restrictions?
        // todo not reentrant
        HostActionsLib.processUnitRevenue(symbol, unitId, amount);
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Restricted actions
    /// @inheritdoc IHost
    function setSettings(IHost.HostSettings memory newSettings) external restricted {
        HostActionsLib.setSettings(newSettings);
    }

    /// @inheritdoc IHost
    function setChainSettings(IHost.HostChainSettings memory newSettings) external restricted {
        HostActionsLib.setChainSettings(newSettings);
    }

    /// @inheritdoc IHost
    function addLiveDAO(bytes memory payload) external restricted {
        HostActionsLib.addLiveDAO(payload);
    }

    /// @inheritdoc IHost
    function refundFor(string calldata symbol, address[] memory receivers) external restricted {
        HostFundingLib.refundFor(symbol, receivers);
    }

    /// @inheritdoc IHost
    function onReceiveCrossChainMessage(uint32 srcEid, bytes32 guid_, bytes memory message_) external restricted {
        HostCrossChainLib.onReceiveCrossChainMessage(srcEid, guid_, message_);
    }

    /// @inheritdoc IHost
    function receiveVotingResults(bytes32 proposalId, bool succeed, bytes memory payload) external payable restricted {
        HostProposalsLib.receiveVotingResults(proposalId, succeed, payload);
    }

    /// @inheritdoc IHost
    function validateProposal(bytes32 proposalId, bool valid, bytes memory payload) external restricted {
        HostProposalsLib.validateProposal(proposalId, valid, payload);
    }

    /// @inheritdoc IHost
    function setContractImplementation(uint kind, address implementation) external restricted {
        HostProxyFactoryLib.setContractImplementation(kind, implementation);
    }

    /// @inheritdoc IHost
    function deployProxy(
        bytes32 salt_,
        address logic,
        bytes memory payload
    ) external restricted returns (address proxy) {
        return HostProxyFactoryLib.deployProxy(salt_, logic, payload, authority());
    }

    //endregion -------------------------------------- Restricted actions

    //region -------------------------------------- Update actions

    /// @inheritdoc IHost
    function updateDAO(string calldata symbol, uint16 action, bytes memory payload, bytes memory metadata) external {
        HostProposalsLib.updateDAO(symbol, action, payload, metadata);
    }

    /// @inheritdoc IHost
    function createBridgedAction(
        string calldata symbol,
        uint16 actionKind,
        uint32[] calldata dstEids,
        bytes[] calldata actionPayloads
    ) external {
        // restrictions are checked below
        HostProposalsLib.updateBridgedDao(symbol, actionKind, dstEids, actionPayloads);
    }

    /// @inheritdoc IHost
    function applyBridgedAction(bytes32 proposalId, bytes calldata actionPayload) external {
        HostUpdateBridgedLib.applyBridgedAction(proposalId, actionPayload);
    }

    //endregion -------------------------------------- Update actions

    //region ---------------------------------------- Update host platform
    /// @inheritdoc IHost
    function announceUpgrade(
        string memory newVersion,
        address[] memory proxies,
        address[] memory newImplementations
    ) external restricted {
        HostUpgradeProxyLib.announceUpgrade(newVersion, proxies, newImplementations);
    }

    /// @inheritdoc IHost
    function upgrade() external restricted {
        HostUpgradeProxyLib.upgrade();
    }

    /// @inheritdoc IHost
    function cancelUpgrade() external restricted {
        HostUpgradeProxyLib.cancelUpgrade();
    }

    //endregion ---------------------------------------- Update host platform
}
