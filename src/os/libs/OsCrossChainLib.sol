// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {IOS} from "../../interfaces/IOS.sol";
import {OsLib} from "./OsLib.sol";
import {IOSBridge} from "../../interfaces/IOSBridge.sol";

/// @notice Basic data types, validation and update logic
library OsCrossChainLib {
    error TooShortCrossChainMessage();
    error UnknownCrossChainMessageKind();

    /// @notice Handle incoming cross-chain message
    /// @custom:restricted Restricted through access manager (only OS bridge can call this function)
    /// @param srcEid LayerZero source endpoint ID
    /// @param guid_ Unique message identifier
    /// @param message_ Message payload
    function onReceiveCrossChainMessage(uint32 srcEid, bytes32 guid_, bytes memory message_) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();

        // todo do we need to check sender here? require(msg.sender == bridge, NotBridge());
        require(message_.length >= 32, TooShortCrossChainMessage());

        uint16 messageKind = abi.decode(message_, (uint16));

        if (messageKind == uint16(IOS.CrossChainMessages.NEW_DAO_SYMBOL_0)) {
            (, string memory daoSymbol) = abi.decode(message_, (uint16, string));

            $.usedSymbols[daoSymbol] = true;

            emit IOS.OnRegisterDaoSymbol(daoSymbol, srcEid, guid_);
        } else if (messageKind == uint16(IOS.CrossChainMessages.DAO_RENAME_SYMBOL_1)) {
            (, string memory oldSymbol, string memory newSymbol) = abi.decode(message_, (uint16, string, string));

            delete $.usedSymbols[oldSymbol];
            $.usedSymbols[newSymbol] = true;

            emit IOS.OnRenameDaoSymbol(oldSymbol, newSymbol, srcEid, guid_);
        } else {
            revert UnknownCrossChainMessageKind();
        }
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
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        address bridge = $.osChainSettings[0].osBridge;
        if (bridge != address(0)) {
            IOSBridge(bridge).sendMessageToAllChains(uint(messageKind), payload);
        }
    }
}
