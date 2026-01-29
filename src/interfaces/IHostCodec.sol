// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBridgedActions} from "./IBridgedActions.sol";

interface IHostCodec {
    function PAYLOAD_API_VERSION() external pure returns (uint16);

    function encode(IBridgedActions.BridgeDaoParams memory data, uint16 version) external pure returns (bytes memory);

    function decodeBridgeDaoParams(bytes memory encoded) external pure returns (IBridgedActions.BridgeDaoParams memory);
}
