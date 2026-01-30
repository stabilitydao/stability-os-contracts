// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBridgedActions} from "./IBridgedActions.sol";
import {ITokenomics} from "./ITokenomics.sol";

interface IHostCodec {
    function PAYLOAD_API_VERSION() external pure returns (uint16);

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
}
