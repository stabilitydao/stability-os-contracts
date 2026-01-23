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

/// @notice Allow to create DAO and update its state according to life cycle
/// [META-ISSUE] DAO must manage properties itself via voting by executing Operating proposals.
contract Host is IHost, Hosted {
    /// @inheritdoc IHosted
    string public constant VERSION = "1.0.0";

    /// @notice Max number of tasks returned by `tasks` function
    uint internal constant MAX_COUNT_TASKS = 25;

    /// @inheritdoc IHosted
    function initialize(address authority_, bytes memory payload) public initializer {
        __Hosted_init(authority_);

        // register all symbols registered on other chains
        IHost.HostInitPayload memory initPayload = abi.decode(payload, (IHost.HostInitPayload));
        HostActionsLib.initHost(initPayload);
    }

    //region -------------------------------------- View

    /// @inheritdoc IHost
    function getDAO(string calldata daoSymbol) external view returns (IDAOData.DaoData memory) {
        return HostViewLib.getDAO(daoSymbol);
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
    function tasks(string calldata daoSymbol) external view returns (IHost.Task[] memory) {
        return HostViewLib.tasks(daoSymbol, MAX_COUNT_TASKS);
    }

    /// @inheritdoc IHost
    function getDAOOwner(string calldata daoSymbol) external view returns (address) {
        return HostViewLib.getDAOOwner(daoSymbol);
    }

    /// @inheritdoc IHost
    function isDaoSymbolInUse(string calldata daoSymbol) external view returns (bool) {
        return HostViewLib.isDaoSymbolInUse(daoSymbol);
    }

    /// @inheritdoc IHost
    function proposal(bytes32 proposalId) external view returns (ITokenomics.Proposal memory) {
        return HostViewLib.proposal(proposalId);
    }

    /// @inheritdoc IHost
    function proposalsLength(string calldata daoSymbol) external view returns (uint) {
        return HostViewLib.proposalsLength(daoSymbol);
    }

    /// @inheritdoc IHost
    function proposalIds(string calldata daoSymbol, uint index, uint count) external view returns (bytes32[] memory) {
        return HostViewLib.proposalIds(daoSymbol, index, count);
    }

    /// @inheritdoc IHost
    function quoteCreateDAO(string calldata daoSymbol) external view returns (uint) {
        return HostCrossChainLib.quoteSendMessageNewSymbol(daoSymbol);
    }

    function unitBalance(string calldata daoSymbol, string calldata unitId) external view returns (uint) {
        return HostViewLib.unitBalance(daoSymbol, unitId);
    }

    function salt(string calldata daoSymbol, uint16 contractIndex, uint chainId) external view returns (bytes32) {
        return HostViewLib.salt(daoSymbol, contractIndex, chainId);
    }

    /// @inheritdoc IHost
    function contractImplementation(uint kind) external view returns (address) {
        return HostProxyFactoryLib.contractImplementation(kind);
    }

    //endregion -------------------------------------- View

    //region -------------------------------------- Actions
    /// @inheritdoc IHost
    function setSettings(IHost.HostSettings memory newSettings) external restricted {
        HostActionsLib.setSettings(newSettings);
    }

    /// @inheritdoc IHost
    function setChainSettings(IHost.HostChainSettings memory newSettings) external restricted {
        HostActionsLib.setChainSettings(newSettings);
    }

    /// @inheritdoc IHost
    function createDAO(
        string calldata name,
        string calldata daoSymbol,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) external payable {
        // no restrictions, anybody can create a DAO
        HostActionsLib.createDAO(name, daoSymbol, activity, params, funding);
    }

    /// @inheritdoc IHost
    function addLiveDAO(IDAOData.DaoDataInput calldata dao) external restricted {
        HostActionsLib.addLiveDAO(dao);
    }

    /// @inheritdoc IHost
    function changePhase(string calldata daoSymbol) external {
        // no restrictions, anybody can call this

        HostViewLib.changePhase(daoSymbol, authority());
    }

    /// @inheritdoc IHost
    function fund(string calldata daoSymbol, uint amount) external {
        // todo not reentrant
        // no restrictions, anybody can call this

        HostFundingLib.fund(daoSymbol, amount);
    }

    /// @inheritdoc IHost
    function receiveVotingResults(bytes32 proposalId, bool succeed, bytes memory payload) external restricted {
        HostProposalsLib.receiveVotingResults(proposalId, succeed, payload);
    }

    /// @inheritdoc IHost
    function refund(string calldata daoSymbol) external {
        // todo not reentrant
        HostFundingLib.refund(daoSymbol);
    }

    /// @inheritdoc IHost
    function refundFor(string calldata daoSymbol, address[] memory receivers) external restricted {
        // todo not reentrant
        HostFundingLib.refundFor(daoSymbol, receivers);
    }

    /// @inheritdoc IHost
    function onReceiveCrossChainMessage(uint32 srcEid, bytes32 guid_, bytes memory message_) external restricted {
        HostCrossChainLib.onReceiveCrossChainMessage(srcEid, guid_, message_);
    }

    /// @inheritdoc IHost
    function processUnitRevenue(string calldata daoSymbol, string memory unitId, uint amount) external {
        // todo no restrictions?
        // todo not reentrant
        HostActionsLib.processUnitRevenue(daoSymbol, unitId, amount);
    }

    /// @inheritdoc IHost
    function setContractImplementation(uint kind, address implementation) external restricted {
        HostProxyFactoryLib.setContractImplementation(kind, implementation);
    }

    /// @inheritdoc IHost
    function deployProxy(bytes32 salt_, address logic, bytes memory payload) external returns (address proxy) {
        return HostProxyFactoryLib.deployProxy(salt_, logic, payload, authority());
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Update actions

    /// @inheritdoc IHost
    function updateImages(string calldata daoSymbol, ITokenomics.DaoImages calldata images) external {
        // restrictions are checked below
        HostProposalsLib.updateImages(daoSymbol, images);
    }

    /// @inheritdoc IHost
    function updateSocials(string calldata daoSymbol, string[] calldata socials) external {
        // restrictions are checked below
        HostProposalsLib.updateSocials(daoSymbol, socials);
    }

    /// @inheritdoc IHost
    function updateUnits(
        string calldata daoSymbol,
        IDAOData.UnitDataInput[] calldata units,
        IDAOData.UnitMetaData[] calldata metadata
    ) external {
        // restrictions are checked below
        HostProposalsLib.updateUnits(daoSymbol, units, metadata);
    }

    /// @inheritdoc IHost
    function updateFunding(string calldata daoSymbol, ITokenomics.Funding calldata funding) external {
        // restrictions are checked below
        HostProposalsLib.updateFunding(daoSymbol, funding);
    }

    /// @inheritdoc IHost
    function updateVesting(string calldata daoSymbol, ITokenomics.Vesting[] calldata vestings) external {
        // restrictions are checked below
        HostProposalsLib.updateVesting(daoSymbol, vestings);
    }

    /// @inheritdoc IHost
    function updateNaming(string calldata daoSymbol, ITokenomics.DaoNames calldata daoNames_) external payable {
        // restrictions are checked below
        HostProposalsLib.updateNaming(daoSymbol, daoNames_);
    }

    /// @inheritdoc IHost
    function updateDaoParameters(
        string calldata daoSymbol,
        ITokenomics.DaoParameters calldata daoParameters_
    ) external {
        // restrictions are checked below
        HostProposalsLib.updateDaoParameters(daoSymbol, daoParameters_);
    }

    /// @inheritdoc IHost
    function updateSalts(
        string calldata daoSymbol,
        uint16[] memory contractIndices,
        bytes32[] memory salt_,
        uint chainId
    ) external {
        // restrictions are checked below
        HostProposalsLib.updateSalts(daoSymbol, contractIndices, salt_, chainId);
    }

    /// @inheritdoc IHost
    function updateBridgedDao(
        string calldata daoSymbol,
        uint targetChainId, // todo array of chains
        uint16 actionKind,
        bytes calldata actionPayload
    ) external {
        // restrictions are checked below
        HostProposalsLib.updateBridgedDao(daoSymbol, targetChainId, actionKind, actionPayload);
    }
    //endregion -------------------------------------- Update actions
}
