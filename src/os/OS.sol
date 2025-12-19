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

    function getChainSettings() external view returns (IOS.OsChainSettings memory) {
        return OsActionsLib.getChainSettings();
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

    /// @notice Set OS chain-depended settings
    function setChainSettings(IOS.OsChainSettings memory newSettings) external {
        // todo only admin
        OsActionsLib.setChainSettings(newSettings);
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

    function receiveVotingResults(bytes32 proposalId, bool succeed) external {
        // todo: restrictions by role

        OsActionsLib.receiveVotingResults(proposalId, succeed);
    }

    //endregion -------------------------------------- Actions

    //region ---------------------------------------- Update actions

    /// @notice Update/create proposal to update implementations of the DAO contracts
    function updateImages(string calldata daoSymbol, ITokenomics.DaoImages calldata images) external {
        // todo restrictions

        OsActionsLib.updateImages(daoSymbol, images);
    }

    /// @notice Update/create proposal to update list of socials of the DAO
    function updateSocials(string calldata daoSymbol, string[] calldata socials) external {
        // todo restrictions

        OsActionsLib.updateSocials(daoSymbol, socials);
    }

    /// @notice Update/create proposal to update tokenomics units of the DAO
    function updateUnits(string calldata daoSymbol, ITokenomics.UnitInfo[] calldata units) external {
        // todo restrictions

        OsActionsLib.updateUnits(daoSymbol, units);
    }

    /// @notice Update/create proposal to update funding rounds of the DAO
    function updateFunding(string calldata daoSymbol, ITokenomics.Funding calldata funding) external {
        // todo restrictions

        OsActionsLib.updateFunding(daoSymbol, funding);
    }

    /// @notice Update/create proposal to update vesting schedules of the DAO
    function updateVesting(string calldata daoSymbol, ITokenomics.Vesting[] calldata vestings) external {
        // todo restrictions

        OsActionsLib.updateVesting(daoSymbol, vestings);
    }

    /// @notice Update/create proposal to update DAO naming (name and symbol)
    function updateNaming(string calldata daoSymbol, ITokenomics.DaoNames calldata daoNames_) external {
        // todo restrictions

        OsActionsLib.updateNaming(daoSymbol, daoNames_);
    }

    /// @notice Update/create proposal to update on-chain DAO parameters
    function updateDaoParameters(string calldata daoSymbol, ITokenomics.DaoParameters calldata daoParameters_) external {
        // todo restrictions

        OsActionsLib.updateDaoParameters(daoSymbol, daoParameters_);
    }

    //endregion ---------------------------------------- Update actions
}