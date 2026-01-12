// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IHost} from "../interfaces/IHost.sol";
import {HostActionsLib} from "./libs/HostActionsLib.sol";
import {HostProposalsLib} from "./libs/HostProposalsLib.sol";
import {HostFundingLib} from "./libs/HostFundingLib.sol";
import {HostCrossChainLib} from "./libs/HostCrossChainLib.sol";
import {HostViewLib} from "./libs/HostViewLib.sol";
import {Controllable2} from "../core/base/Controllable2.sol";
import {IControllable2} from "../interfaces/IControllable2.sol";

/// @notice Allow to create DAO and update its state according to life cycle
/// [META-ISSUE] DAO must manage properties itself via voting by executing Operating proposals.
contract Host is IHost, Controllable2 {
    /// @inheritdoc IControllable2
    string public constant VERSION = "1.0.0";

    /// @notice Max number of tasks returned by `tasks` function
    uint internal constant MAX_COUNT_TASKS = 25;

    /// @inheritdoc IControllable2
    function initialize(address authority_, bytes memory payload) public initializer {
        __Controllable_init(authority_);

        // register all symbols registered on other chains
        IHost.OsInitPayload memory initPayload = abi.decode(payload, (IHost.OsInitPayload));
        HostActionsLib.initOS(initPayload);
    }

    //region -------------------------------------- View

    /// @inheritdoc IHost
    function getDAO(string calldata daoSymbol) external view returns (ITokenomics.DaoData memory) {
        return HostViewLib.getDAO(daoSymbol);
    }

    /// @inheritdoc IHost
    function getSettings() external view returns (IHost.OsSettings memory) {
        return HostViewLib.getSettings();
    }

    /// @inheritdoc IHost
    function getChainSettings() external view returns (IHost.OsChainSettings memory) {
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

    //endregion -------------------------------------- View

    //region -------------------------------------- Actions
    /// @inheritdoc IHost
    function setSettings(IHost.OsSettings memory newSettings) external restricted {
        HostActionsLib.setSettings(newSettings);
    }

    /// @inheritdoc IHost
    function setChainSettings(IHost.OsChainSettings memory newSettings) external restricted {
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
    function addLiveDAO(ITokenomics.DaoData calldata dao) external restricted {
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
    function receiveVotingResults(bytes32 proposalId, bool succeed) external restricted {
        HostProposalsLib.receiveVotingResults(proposalId, succeed);
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
    function updateUnits(string calldata daoSymbol, ITokenomics.UnitInfo[] calldata units) external {
        // restrictions are checked below
        HostProposalsLib.updateUnits(daoSymbol, units);
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

    //endregion -------------------------------------- Update actions
}
