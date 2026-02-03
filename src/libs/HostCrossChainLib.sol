// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {IHost} from "../interfaces/IHost.sol";
import {HostLib} from "./HostLib.sol";
import {IHostBridge} from "../interfaces/IHostBridge.sol";
import {HostConfigLib} from "./HostConfigLib.sol";

/// @notice Basic data types, validation and update logic
library HostCrossChainLib {
    error TooShortCrossChainMessage();
    error UnknownCrossChainMessageKind();

    /// @notice Handle incoming cross-chain message
    /// @custom:restricted Restricted through access manager (only OS bridge can call this function)
    /// @param srcEid LayerZero source endpoint ID
    /// @param guid_ Unique message identifier
    /// @param message_ Message payload
    function onReceiveCrossChainMessage(uint32 srcEid, bytes32 guid_, bytes memory message_) external {
        console.log("onReceiveCrossChainMessage", block.chainid);
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        // todo do we need to check sender here? require(msg.sender == bridge, NotBridge());
        require(message_.length >= 32, TooShortCrossChainMessage());

        uint16 messageKind = abi.decode(message_, (uint16));
        console.log("onReceiveCrossChainMessage message kind", messageKind);

        if (messageKind == uint16(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0)) {
            string memory symbol = unpackMessageNewDaoSymbol(message_);

            $.daoUids[symbol] = HostLib.getDaoUidStub();

            emit IHost.OnRegisterDaoSymbol(symbol, srcEid, guid_);
        } else if (messageKind == uint16(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1)) {
            (string memory oldSymbol, string memory newSymbol) = unpackMessageRenameSymbol(message_);

            uint daoUid = $.daoUids[oldSymbol];
            delete $.daoUids[oldSymbol];
            $.daoUids[newSymbol] = daoUid;

            emit IHost.OnRenameDaoSymbol(oldSymbol, newSymbol, srcEid, guid_);
        } else if (messageKind == uint16(IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2)) {
            (uint16 actionKind, uint daoUid, bytes32 actionHash) = unpackMessageBridgedActionHash(message_);
            console.log("actionKind, daoUid, actionHash", actionKind, daoUid, uint(actionHash));

            $.bridgedActionHashes[actionHash] = HostLib.BridgedActionLocal({
                daoUid: daoUid,
                bridgedActionHeader: HostLib.packBridgedActionHeader(
                    HostLib.BridgedActionHeader({actionKind: actionKind, applied: false})
                )
            });

            emit IHost.OnBridgedDaoAction(actionHash, actionKind, srcEid, guid_);
        } else {
            revert UnknownCrossChainMessageKind();
        }
    }

    //region ----------------------------------------- Pack/Unpack cross-chain messages
    function packMessageNewDaoSymbol(string memory symbol) internal pure returns (bytes memory message) {
        return abi.encode(uint16(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0), symbol);
    }

    function unpackMessageNewDaoSymbol(bytes memory message) internal pure returns (string memory symbol) {
        (, symbol) = abi.decode(message, (uint16, string));
    }

    function packMessageRenameSymbol(
        string memory oldSymbol,
        string memory newSymbol
    ) internal pure returns (bytes memory message) {
        return abi.encode(uint16(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1), oldSymbol, newSymbol);
    }

    function unpackMessageRenameSymbol(bytes memory message)
        internal
        pure
        returns (string memory oldSymbol, string memory newSymbol)
    {
        (, oldSymbol, newSymbol) = abi.decode(message, (uint16, string, string));
    }

    function packMessageBridgedActionHash(
        uint16 actionKind,
        uint daoUid,
        bytes32 actionHash
    ) internal pure returns (bytes memory message) {
        return abi.encode(uint16(IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2), actionKind, daoUid, actionHash);
    }

    function unpackMessageBridgedActionHash(bytes memory message)
        internal
        pure
        returns (uint16 actionKind, uint daoUid, bytes32 actionHash)
    {
        (, actionKind, daoUid, actionHash) = abi.decode(message, (uint16, uint16, uint, bytes32));
    }

    //endregion ----------------------------------------- Pack/Unpack cross-chain messages

    //region ----------------------------------------- Quote and send cross-chain messages
    /// @notice Send cross-chain notification about new DAO symbol registration.
    function sendMessageToAllChains(IHost.CrossChainMessages messageKind, bytes memory message) internal {
        address bridge = HostConfigLib.getHostChainSettings().hostBridge;
        _sendCrossChainMessageToAllChains(messageKind, message, bridge);
    }

    /// @notice Send cross-chain notification about new DAO symbol registration.
    function sendMessage(uint32 dstEid, IHost.CrossChainMessages messageKind, bytes memory message) internal {
        address bridge = HostConfigLib.getHostChainSettings().hostBridge;
        _sendCrossChainMessage(dstEid, messageKind, message, bridge);
    }

    function quoteMessageToAllChains(
        IHost.CrossChainMessages messageKind,
        bytes memory message
    ) external view returns (uint) {
        address bridge = HostConfigLib.getHostChainSettings().hostBridge;
        return IHostBridge(bridge).quoteSendMessageToAllChains(uint(messageKind), message);
    }

    function quoteMessage(
        uint32 dstEid,
        IHost.CrossChainMessages messageKind,
        bytes memory message
    ) internal view returns (uint) {
        return _quoteMessage(dstEid, messageKind, message, HostConfigLib.getHostChainSettings().hostBridge);
    }

    //endregion ----------------------------------------- Quote and send cross-chain messages

    //region ----------------------------------------- Internal utils
    /// @notice Send cross-chain message about DAO event
    function _sendCrossChainMessageToAllChains(
        IHost.CrossChainMessages messageKind,
        bytes memory payload,
        address bridge_
    ) internal {
        uint totalFee = IHostBridge(bridge_).quoteSendMessageToAllChains(uint(messageKind), payload);
        require(msg.value >= totalFee, IHost.NotEnoughNativeProvided(totalFee));
        IHostBridge(bridge_).sendMessageToAllChains{value: totalFee}(uint(messageKind), payload);
    }

    /// @notice Send cross-chain message about DAO event
    function _sendCrossChainMessage(
        uint32 dstEid,
        IHost.CrossChainMessages messageKind,
        bytes memory payload,
        address bridge_
    ) internal {
        console.log("_sendCrossChainMessage.message kind", uint(messageKind), dstEid);

        uint fee = IHostBridge(bridge_).quoteSendMessage(dstEid, uint(messageKind), payload);
        require(msg.value >= fee, IHost.NotEnoughNativeProvided(fee));
        IHostBridge(bridge_).sendMessage{value: fee}(dstEid, uint(messageKind), payload, fee);
    }

    function _quoteMessage(
        uint32 dstEid,
        IHost.CrossChainMessages messageKind,
        bytes memory message,
        address bridge
    ) internal view returns (uint) {
        return IHostBridge(bridge).quoteSendMessage(dstEid, uint(messageKind), message);
    }

    //endregion ----------------------------------------- Internal utils
}
