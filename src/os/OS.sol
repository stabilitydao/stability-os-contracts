// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IOS} from "../interfaces/IOS.sol";
import {OsActionsLib} from "./libs/OsActionsLib.sol";
import {OsProposalsLib} from "./libs/OsProposalsLib.sol";
import {OsFundingLib} from "./libs/OsFundingLib.sol";
import {OsCrossChainLib} from "./libs/OsCrossChainLib.sol";
import {OsViewLib} from "./libs/OsViewLib.sol";
import {Controllable2} from "../core/base/Controllable2.sol";
import {IControllable2} from "../interfaces/IControllable2.sol";

/// @notice Allow to create DAO and update its state according to life cycle
/// [META-ISSUE] DAO must manage properties itself via voting by executing Operating proposals.
contract OS is IOS, Controllable2 {
    /// @inheritdoc IControllable2
    string public constant VERSION = "1.0.0";

    /// @notice Max number of tasks returned by `tasks` function
    uint internal constant MAX_COUNT_TASKS = 25;

    /// @inheritdoc IControllable2
    function initialize(address authority_, bytes memory payload) public initializer {
        __Controllable_init(authority_);

        // register all symbols registered on other chains
        IOS.OsInitPayload memory initPayload = abi.decode(payload, (IOS.OsInitPayload));
        OsActionsLib.initOS(initPayload);
    }

    //region -------------------------------------- View

    /// @inheritdoc IOS
    function getDAO(string calldata daoSymbol) external view returns (ITokenomics.DaoData memory) {
        return OsViewLib.getDAO(daoSymbol);
    }

    /// @inheritdoc IOS
    function getSettings() external view returns (IOS.OsSettings memory) {
        return OsViewLib.getSettings();
    }

    /// @inheritdoc IOS
    function getChainSettings() external view returns (IOS.OsChainSettings memory) {
        return OsViewLib.getChainSettings();
    }

    /// @inheritdoc IOS
    function tasks(string calldata daoSymbol) external view returns (IOS.Task[] memory) {
        return OsViewLib.tasks(daoSymbol, MAX_COUNT_TASKS);
    }

    /// @inheritdoc IOS
    function getDAOOwner(string calldata daoSymbol) external view returns (address) {
        return OsViewLib.getDAOOwner(daoSymbol);
    }

    /// @inheritdoc IOS
    function isDaoSymbolInUse(string calldata daoSymbol) external view returns (bool) {
        return OsViewLib.isDaoSymbolInUse(daoSymbol);
    }

    /// @inheritdoc IOS
    function proposal(bytes32 proposalId) external view returns (ITokenomics.Proposal memory) {
        return OsViewLib.proposal(proposalId);
    }

    /// @inheritdoc IOS
    function proposalsLength(string calldata daoSymbol) external view returns (uint) {
        return OsViewLib.proposalsLength(daoSymbol);
    }

    /// @inheritdoc IOS
    function proposalIds(string calldata daoSymbol, uint index, uint count) external view returns (bytes32[] memory) {
        return OsViewLib.proposalIds(daoSymbol, index, count);
    }

    //endregion -------------------------------------- View

    //region -------------------------------------- Actions
    /// @inheritdoc IOS
    function setSettings(IOS.OsSettings memory newSettings) external restricted {
        OsActionsLib.setSettings(newSettings);
    }

    /// @inheritdoc IOS
    function setChainSettings(IOS.OsChainSettings memory newSettings) external restricted {
        OsActionsLib.setChainSettings(newSettings);
    }

    /// @inheritdoc IOS
    function createDAO(
        string calldata name,
        string calldata daoSymbol,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) external {
        // no restrictions, anybody can create a DAO
        OsActionsLib.createDAO(name, daoSymbol, activity, params, funding);
    }

    /// @inheritdoc IOS
    function addLiveDAO(ITokenomics.DaoData calldata dao) external restricted {
        OsActionsLib.addLiveDAO(dao);
    }

    /// @inheritdoc IOS
    function changePhase(string calldata daoSymbol) external {
        // no restrictions, anybody can call this

        OsViewLib.changePhase(daoSymbol, authority());
    }

    /// @inheritdoc IOS
    function fund(string calldata daoSymbol, uint amount) external {
        // todo not reentrant
        // no restrictions, anybody can call this

        OsFundingLib.fund(daoSymbol, amount);
    }

    /// @inheritdoc IOS
    function receiveVotingResults(bytes32 proposalId, bool succeed) external restricted {
        OsProposalsLib.receiveVotingResults(proposalId, succeed);
    }

    /// @inheritdoc IOS
    function refund(string calldata daoSymbol) external {
        // todo not reentrant
        OsFundingLib.refund(daoSymbol);
    }

    /// @inheritdoc IOS
    function refundFor(string calldata daoSymbol, address[] memory receivers) external restricted {
        // todo not reentrant
        OsFundingLib.refundFor(daoSymbol, receivers);
    }

    /// @inheritdoc IOS
    function onReceiveCrossChainMessage(uint32 srcEid, bytes32 guid_, bytes memory message_) external restricted {
        OsCrossChainLib.onReceiveCrossChainMessage(srcEid, guid_, message_);
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Update actions

    /// @inheritdoc IOS
    function updateImages(string calldata daoSymbol, ITokenomics.DaoImages calldata images) external {
        // restrictions are checked below
        OsProposalsLib.updateImages(daoSymbol, images);
    }

    /// @inheritdoc IOS
    function updateSocials(string calldata daoSymbol, string[] calldata socials) external {
        // restrictions are checked below
        OsProposalsLib.updateSocials(daoSymbol, socials);
    }

    /// @inheritdoc IOS
    function updateUnits(string calldata daoSymbol, ITokenomics.UnitInfo[] calldata units) external {
        // restrictions are checked below
        OsProposalsLib.updateUnits(daoSymbol, units);
    }

    /// @inheritdoc IOS
    function updateFunding(string calldata daoSymbol, ITokenomics.Funding calldata funding) external {
        // restrictions are checked below
        OsProposalsLib.updateFunding(daoSymbol, funding);
    }

    /// @inheritdoc IOS
    function updateVesting(string calldata daoSymbol, ITokenomics.Vesting[] calldata vestings) external {
        // restrictions are checked below
        OsProposalsLib.updateVesting(daoSymbol, vestings);
    }

    /// @inheritdoc IOS
    function updateNaming(string calldata daoSymbol, ITokenomics.DaoNames calldata daoNames_) external {
        // restrictions are checked below
        OsProposalsLib.updateNaming(daoSymbol, daoNames_);
    }

    /// @inheritdoc IOS
    function updateDaoParameters(
        string calldata daoSymbol,
        ITokenomics.DaoParameters calldata daoParameters_
    ) external {
        // restrictions are checked below
        OsProposalsLib.updateDaoParameters(daoSymbol, daoParameters_);
    }

    //endregion -------------------------------------- Update actions
}
