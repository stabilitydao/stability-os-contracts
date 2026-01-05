// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// import {IOSBridge} from "../interfaces/IOSBridge.sol";

contract MockOsBridge {
    mapping(uint => bytes) public receivedMessages;

    function quoteSendMessageToAllChains(uint messageKind, bytes memory message_) external pure returns (uint) {
        return 0;
    }
    function sendMessageToAllChains(uint messageKind, bytes memory message_) external {
        receivedMessages[messageKind] = message_;
    }
}
