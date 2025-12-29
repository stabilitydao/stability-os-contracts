// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOS} from "../../interfaces/IOS.sol";
import {OsLib} from "./OsLib.sol";
import {IOSBridge} from "../../interfaces/IOSBridge.sol";

/// @notice Basic data types, validation and update logic
library OsCrossChainLib {
    /// @notice Handle incoming cross-chain message
    /// @custom:restricted Restricted through access manager (only OS bridge can call this function)
    /// @param srcEid LayerZero source endpoint ID
    /// @param guid_ Unique message identifier
    /// @param message_ Message payload
    function onReceiveCrossChainMessage(uint32 srcEid, bytes32 guid_, bytes memory message_) external {

    }

    /// @notice Send cross-chain notification about new DAO symbol registration.
    function sendMessageNewSymbol(string memory daoSymbol) internal {
        bytes memory payload = abi.encode(uint16(IOS.CrossChainMessages.NEW_DAO_SYMBOL_0), daoSymbol);
        _sendCrossChainMessage(IOS.CrossChainMessages.NEW_DAO_SYMBOL_0, payload);
    }

    /// @notice Send cross-chain notification about updating DAO symbol.
    function sendMessageUpdateSymbol(string memory oldSymbol, string memory newSymbol) internal {
        bytes memory payload = abi.encode(uint16(IOS.CrossChainMessages.DAO_RENAME_SYMBOL_1), oldSymbol, newSymbol);
        _sendCrossChainMessage(IOS.CrossChainMessages.DAO_RENAME_SYMBOL_1, payload);
    }

    /// @notice Send cross-chain message about DAO event
    function _sendCrossChainMessage(IOS.CrossChainMessages messageKind, bytes memory payload) internal {
//        address bridge = address(0); // todo
//        IOSBridge(bridge).sendMessageToAllChains(uint(messageKind), payload);
    }

}
