// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IOS} from "../interfaces/IOS.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {OsLib} from "./libs/OsLib.sol"; // todo upgradable

/// @notice Allow to create DAO and update its state according to life cycle
contract OS is /* IOS, */ AccessManager {
    constructor(address initialAdmin) AccessManager(initialAdmin) {
        // todo
    }

    //region -------------------------------------- View
    function getDAO(string calldata daoSymbol) external view returns (ITokenomics.DaoData memory) {
        return OsLib.getDAO(daoSymbol);
    }

    //endregion -------------------------------------- View

    //region -------------------------------------- Actions

    function createDAO(
        string calldata name,
        string calldata daoSymbol,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) external {
        // no restrictions, anyone can create a DAO
        OsLib.createDAO(name, daoSymbol, activity, params, funding);
    }

    //endregion -------------------------------------- Actions

}