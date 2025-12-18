// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IOS} from "../interfaces/IOS.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";  // todo upgradable
import {OsActionsLib} from "./libs/OsActionsLib.sol";

/// @notice Allow to create DAO and update its state according to life cycle
contract OS is /* IOS, */ AccessManager {
    /// @notice Max number of tasks returned by `tasks` function
    uint constant internal MAX_COUNT_TASKS = 25;

    constructor(address initialAdmin) AccessManager(initialAdmin) {
        // todo
    }

    //region -------------------------------------- View
    function getDAO(string calldata daoSymbol) external view returns (ITokenomics.DaoData memory) {
        return OsActionsLib.getDAO(daoSymbol);
    }

    function getSettings() external view returns (IOS.OsSettings memory) {
        return OsActionsLib.getSettings();
    }

    function tasks(string calldata daoSymbol) external view returns (IOS.Task[] memory) {
        return OsActionsLib.tasks(daoSymbol, MAX_COUNT_TASKS);
    }

    //endregion -------------------------------------- View

    //region -------------------------------------- Actions
    /// @notice Set OS settings
    function setSettings(IOS.OsSettings memory newSettings) external {
        // todo only admin
        OsActionsLib.setSettings(newSettings);
    }

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

    function addLiveDAO(ITokenomics.DaoData calldata dao) external {
        // todo _onlyVerifier

        OsActionsLib.addLiveDAO(dao);
    }

    function changePhase(string calldata daoSymbol) external {
        // no restrictions, anybody can call this

        OsActionsLib.changePhase(daoSymbol);
    }

    function fund(string calldata daoSymbol, uint256 amount) external {
        // no restrictions, anybody can call this

        OsActionsLib.fund(daoSymbol, amount);
    }

    function receiveVotingResults(string calldata proposalId, bool succeed) external {
        // todo: restrictions

        OsActionsLib.receiveVotingResults(proposalId, succeed);
    }

    //endregion -------------------------------------- Actions

}