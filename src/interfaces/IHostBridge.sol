// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IHostBridge {
    error UnsupportedMessageKind(uint messageKind);
    error ZeroGasLimit(uint messageKind);

    event SendMessage(uint32 indexed dstEid, bytes payload);
    event SetHost(address os);
    event AddEndpoint(uint32 endpointId);
    event RemoveEndpoint(uint32 endpointId);
    event SetGasLimit(uint messageKind, uint128 gasLimit);

    /// @notice Quote total fee for sending message to the given chain
    /// @param dstEid_ LayerZero endpoint ID of the destination chain
    /// @param messageKind See IHost.CrossChainMessages
    /// @param message_ The message (encoded to bytes) to send to destination OS
    /// @return fee Fee in native token for sending the message to the given chain
    function quoteSendMessage(uint32 dstEid_, uint messageKind, bytes memory message_) external view returns (uint fee);

    /// @notice Send message to a remote HostBridge on another chain.
    /// @custom:restricted Only HOST contracts can call this function
    /// @param dstEid_ LayerZero endpoint ID of the destination chain
    /// @param messageKind See IHost.CrossChainMessages
    /// @param message_ The message (encoded to bytes) to send to destination OS
    /// @param fee Fee in native token for sending the message to the given chain
    function sendMessage(uint32 dstEid_, uint messageKind, bytes memory message_, uint fee) external payable;

    /// @notice Quote total fee for sending message to all registered chains
    /// @param messageKind See IHost.CrossChainMessages
    /// @param message_ The message (encoded to bytes) to send to destination OS
    /// @return totalFee Total fee in native token for sending the message to all registered chains
    function quoteSendMessageToAllChains(uint messageKind, bytes memory message_) external view returns (uint totalFee);

    /// @notice Send message to all registered chains
    /// @custom:restricted Only OS contracts can call this function
    function sendMessageToAllChains(uint messageKind, bytes memory message_) external payable;

    /// @notice Get supported chains endpoint LayerZero IDs
    function endpoints() external view returns (uint32[] memory);

    /// @notice Get gas limit for a specific message kind
    /// @param messageKind See IOS.CrossChainMessages
    function gasLimit(uint messageKind) external view returns (uint128);

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
