// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
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
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        // todo do we need to check sender here? require(msg.sender == bridge, NotBridge());
        require(message_.length >= 32, TooShortCrossChainMessage());

        uint16 messageKind = abi.decode(message_, (uint16));

        if (messageKind == uint16(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0)) {
            (, string memory daoSymbol) = abi.decode(message_, (uint16, string));

            $.daoUids[daoSymbol] = HostLib.getDaoUidStub();

            emit IHost.OnRegisterDaoSymbol(daoSymbol, srcEid, guid_);
        } else if (messageKind == uint16(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1)) {
            (, string memory oldSymbol, string memory newSymbol) = abi.decode(message_, (uint16, string, string));

            delete $.daoUids[oldSymbol];
            $.daoUids[newSymbol] = HostLib.getDaoUidStub();

            emit IHost.OnRenameDaoSymbol(oldSymbol, newSymbol, srcEid, guid_);
        } else {
            revert UnknownCrossChainMessageKind();
        }
    }

    /// @notice Send cross-chain notification about new DAO symbol registration.
    function sendMessageNewSymbol(string memory daoSymbol) internal {
        bytes memory payload = abi.encode(uint16(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0), daoSymbol);
        _sendCrossChainMessage(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0, payload);
    }

    /// @notice Quote cost to register new DAO symbol
    /// @param daoSymbol Symbol of new DAO
    /// @return Cost in native currency to create the DAO using {createDAO(daoSymbol)}
    function quoteSendMessageNewSymbol(string calldata daoSymbol) external view returns (uint) {
        bytes memory payload = abi.encode(uint16(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0), daoSymbol);
        address bridge = HostConfigLib.getHostChainSettings().hostBridge;
        return bridge == address(0)
            ? 0
            : IHostBridge(bridge).quoteSendMessageToAllChains(uint(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0), payload);
    }

    /// @notice Send cross-chain notification about updating DAO symbol.
    function sendMessageUpdateSymbol(string memory oldSymbol, string memory newSymbol) internal {
        bytes memory payload = abi.encode(uint16(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1), oldSymbol, newSymbol);
        _sendCrossChainMessage(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1, payload);
    }

    /// @notice Send cross-chain message about DAO event
    function _sendCrossChainMessage(IHost.CrossChainMessages messageKind, bytes memory payload) internal {
        address bridge = HostConfigLib.getHostChainSettings().hostBridge;
        if (bridge != address(0)) {
            uint totalFee = IHostBridge(bridge).quoteSendMessageToAllChains(uint(messageKind), payload);
            require(msg.value >= totalFee, IHost.NotEnoughNativeProvided(totalFee));
            IHostBridge(bridge).sendMessageToAllChains{value: totalFee}(uint(messageKind), payload);
        }
    }
}
