// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IDAOData} from "./IDAOData.sol";

interface IDataReader {
    function getDAO(string calldata daoSymbol) external view returns (IDAOData.DaoData memory);
    function proposal(bytes32 proposalId) external view returns (ITokenomics.Proposal memory);
}