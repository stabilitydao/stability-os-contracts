// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IDAOData} from "./IDAOData.sol";

interface IDataReader {
    /// @notice Get DAO data by its symbol
    function getDAO(string calldata symbol) external view returns (IDAOData.DaoData memory);

    /// @notice Governance proposals. Can be created only at initialChain of DAO.
    /// @param proposalId The unique identifier of the proposal
    function proposal(bytes32 proposalId) external view returns (ITokenomics.Proposal memory);

    /// @notice Get token name
    /// @param daoUid DAO unique identifier
    /// @param namingTokenKind Naming token kind, see IHost.NamingTokenKind constants
    function getTokenName(uint daoUid, uint namingTokenKind) external view returns (string memory);

    /// @notice Get token symbol
    /// @param daoUid DAO unique identifier
    /// @param namingTokenKind Naming token kind, see IHost.NamingTokenKind constants
    function getTokenSymbol(uint daoUid, uint namingTokenKind) external view returns (string memory);
}
