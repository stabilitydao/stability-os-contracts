// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MessagingFee} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";

interface IOSBridge {

    event SendMessage(uint32 indexed dstEid, bytes payload);

    /// @notice Quote the gas needed to pay for sending price message to the given destination chain endpoint ID.
    /// @param dstEid_ Destination chain endpoint ID, see https://docs.layerzero.network/v2/concepts/glossary#endpoint-id
    /// @param options_ Additional options for the message. Use OptionsBuilder.addExecutorLzReceiveOption()
    /// @param message_ The message (encoded to bytes) to send to destination OS
    /// @return fee A `MessagingFee` struct containing the calculated gas fee in either the native token or ZRO token.
    function quoteSendMessage(uint32 dstEid_, bytes memory options_, bytes memory message_) external view returns (MessagingFee memory fee);

    /// @notice Send message to a remote OSBridge on another chain.
    /// @custom:restricted Only OS contracts can call this function
    /// @param dstEid_ Destination chain endpoint ID, see https://docs.layerzero.network/v2/concepts/glossary#endpoint-id
    /// @param options_ Additional options for the message. Use OptionsBuilder.addExecutorLzReceiveOption()
    /// @param message_ The message (encoded to bytes) to send to destination OS
    /// @param fee_ A `MessagingFee` struct containing the gas
    function sendMessage(uint32 dstEid_, bytes memory options_, bytes memory message_, MessagingFee memory fee_) external;
}