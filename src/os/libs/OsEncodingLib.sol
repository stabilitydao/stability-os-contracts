// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics, IDAOUnit} from "../../interfaces/ITokenomics.sol";

/// @notice Library for encoding and decoding proposal payloads
library OsEncodingLib {
    // todo New items can be added to the structures. We need to be able to decode old versions.
    // Decode / encode helpers. Currently thin wrappers around abi.decode / abi.encode.
    // Will replace implementations later if needed


    function decodeDaoImages(bytes memory payload) internal pure returns (ITokenomics.DaoImages memory) {
        return abi.decode(payload, (ITokenomics.DaoImages));
    }
    function encodeDaoImages(ITokenomics.DaoImages memory data) internal pure returns (bytes memory) {
        return abi.encode(data);
    }

    function decodeSocials(bytes memory payload) internal pure returns (string[] memory) {
        return abi.decode(payload, (string[]));
    }
    function encodeSocials(string[] memory data) internal pure returns (bytes memory) {
        return abi.encode(data);
    }

    function decodeUnits(bytes memory payload) internal pure returns (IDAOUnit.UnitInfo[] memory) {
        return abi.decode(payload, (IDAOUnit.UnitInfo[]));
    }
    function encodeUnits(IDAOUnit.UnitInfo[] memory data) internal pure returns (bytes memory) {
        return abi.encode(data);
    }

    function decodeFunding(bytes memory payload) internal pure returns (ITokenomics.Funding memory) {
        return abi.decode(payload, (ITokenomics.Funding));
    }
    function encodeFunding(ITokenomics.Funding memory data) internal pure returns (bytes memory) {
        return abi.encode(data);
    }

    function decodeVesting(bytes memory payload) internal pure returns (ITokenomics.Vesting[] memory) {
        return abi.decode(payload, (ITokenomics.Vesting[]));
    }
    function encodeVesting(ITokenomics.Vesting[] memory data) internal pure returns (bytes memory) {
        return abi.encode(data);
    }

    function decodeDaoNames(bytes memory payload) internal pure returns (ITokenomics.DaoNames memory) {
        return abi.decode(payload, (ITokenomics.DaoNames));
    }
    function encodeDaoNames(ITokenomics.DaoNames memory data) internal pure returns (bytes memory) {
        return abi.encode(data);
    }

    function decodeDaoParameters(bytes memory payload) internal pure returns (ITokenomics.DaoParameters memory) {
        return abi.decode(payload, (ITokenomics.DaoParameters));
    }
    function encodeDaoParameters(ITokenomics.DaoParameters memory data) internal pure returns (bytes memory) {
        return abi.encode(data);
    }


    function encodeSymbol(string memory daoSymbol) internal pure returns (bytes memory) {
        return abi.encode(daoSymbol);
    }

    function encodePairSymbols(string memory oldSymbol, string memory newSymbol) internal pure returns (bytes memory) {
        return abi.encode(oldSymbol, newSymbol);
    }
}