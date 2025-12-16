// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../../interfaces/ITokenomics.sol";
import {IOS} from "../../interfaces/IOS.sol";


library OsLib {
    // keccak256(abi.encode(uint(keccak256("erc7201:stability-os-contracts.OS")) - 1)) & ~bytes32(uint(0xff));
    bytes32 internal constant OS_STORAGE_LOCATION = 0; // todo

    //region -------------------------------------- Data types

    /// @custom:storage-location erc7201:stability.Recovery
    struct OsStorage {
        /// @notice Data of each registered DAO
        /// @dev Full DAO data is stored on initial chain only. Other chains have only records in {usedSymbols}
        mapping(string daoSymbol => ITokenomics.DaoData) daos;

        /// @notice Full list of all used DAO symbols (on any chains)
        mapping(string daoSymbol => bool registered) usedSymbols;

        /// @notice All registered proposals. Proposal Id is generated as hash of (daoSymbol, proposalId)
        mapping(byte32 proposalUid => ITokenomics.Proposal) proposals;

        /// @notice List of all proposals for each DAO, proposalId is a string unique for the given DAO
        mapping(string daoSymbol => string[] proposalIds) daoProposals;

        /// @notice 0 => Settings of the OS. Mapping is used to be able to add new fields to OSSettings later
        mapping(uint => IOS.OSSettings) osSettings;
    }

    //endregion -------------------------------------- Data types

    //region -------------------------------------- View

    //endregion -------------------------------------- View

    //region -------------------------------------- Actions

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Internal utils

    //endregion -------------------------------------- Internal utils


}