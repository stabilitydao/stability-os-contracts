// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBridgedActions} from "./IBridgedActions.sol";
import {ITokenomics} from "./ITokenomics.sol";
import {IDAOData} from "./IDAOData.sol";

interface IHostCodec {
    function PAYLOAD_API_VERSION() external pure returns (uint16);

    function encode(ITokenomics.DaoImages memory images, uint16 version) external pure returns (bytes memory);

    function decodeImages(bytes memory encoded) external pure returns (ITokenomics.DaoImages memory images);

    function encode(string[] memory socials) external pure returns (bytes memory);

    function decodeSocials(bytes memory encoded) external pure returns (string[] memory socials);

    function encode(ITokenomics.DaoNames memory data, uint16 version) external pure returns (bytes memory);

    function decodeDaoNames(bytes memory encoded) external pure returns (ITokenomics.DaoNames memory data);

    function encode(IDAOData.UnitDataInput[] memory units, uint16 version) external pure returns (bytes memory);

    function decodeUnits(bytes memory encoded) external pure returns (IDAOData.UnitDataInput[] memory units);

    function encode(IDAOData.UnitMetaData[] memory metadata, uint16 version) external pure returns (bytes memory);

    function decodeUnitsMetadata(bytes memory encoded) external pure returns (IDAOData.UnitMetaData[] memory metadata);

    function encode(ITokenomics.Funding memory funding, uint16 version) external pure returns (bytes memory);

    function decodeFunding(bytes memory encoded) external pure returns (ITokenomics.Funding memory funding);

    function encode(ITokenomics.Vesting[] memory vestings, uint16 version) external pure returns (bytes memory);

    function decodeVesting(bytes memory encoded) external pure returns (ITokenomics.Vesting[] memory vestings);

    function encode(IBridgedActions.BridgeDaoParams memory data, uint16 version) external pure returns (bytes memory);

    function decodeBridgeDaoParams(bytes memory encoded) external pure returns (IBridgedActions.BridgeDaoParams memory);

    function encode(ITokenomics.DaoParameters memory data, uint16 version) external pure returns (bytes memory);

    function decodeDaoParameters(bytes memory encoded) external pure returns (ITokenomics.DaoParameters memory);

    function encode(ITokenomics.DaoChainSettings memory data, uint16 version) external pure returns (bytes memory);

    function decodeDaoChainSettings(bytes memory encoded) external pure returns (ITokenomics.DaoChainSettings memory);

    function encode(
        uint16[] memory contractIndices,
        bytes32[] memory salt,
        uint16 version
    ) external pure returns (bytes memory);

    function decodeSalt(bytes memory encoded)
        external
        pure
        returns (uint16[] memory contractIndices, bytes32[] memory salt);

    // removed from contract to reduce its size
    //    function encode(IDAOData.DaoDataInput calldata dao) external pure returns (bytes memory payload);
    //
    //    function decodeDaoDataInput(bytes memory payload) external pure returns (IDAOData.DaoDataInput memory dao);
}
