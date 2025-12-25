// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MessagingFee} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";

interface IOSBridge {

    error UnsupportedMessageKind(uint messageKind);

    event SendMessage(uint32 indexed dstEid, bytes payload);
    event SetOs(address os);
    event AddEndpoint(uint32 endpointId);
    event RemoveEndpoint(uint32 endpointId);
    event SetGasLimit(uint messageKind, uint128 gasLimit);

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

    /// @notice Send message to all registered chains
    function sendMessageToAllChains(uint messageKind, bytes memory message_) external;

    /// @notice Get OS contract address on the current chain
    function getOs() external view returns (address);

    /// @notice Get supported chains endpoint LayerZero IDs
    function endpoints() external view returns (uint32[] memory);

    /// @notice Get gas limit for a specific message kind
    /// @param messageKind See IOS.CrossChainMessages
    function gasLimit(uint messageKind) external view returns (uint128);

    /// @notice Set OS contract address on the current chain
    /// @param os_ Address of the OS contract
    /// @custom:restricted Only admin
    function setOs(address os_) external;

    /// @notice Add supported chains by their endpoint LayerZero IDs
    /// @param eids_ Array of chain endpoint LayerZero IDs to add
    function addEndpoint(uint32[] memory eids_) external;

    /// @notice Remove supported chains by their endpoint LayerZero IDs
    /// @param eids_ Array of chain endpoint LayerZero IDs to remove
    function removeEndpoint(uint32[] memory eids_) external;

    /// @notice Set gas limit for a specific message kind
    /// @param messageKind See IOS.CrossChainMessages
    /// @param gasLimit_ Gas limit to set
    function setGasLimit(uint messageKind, uint128 gasLimit_) external;
}