// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {console, Vm} from "forge-std/Test.sol";
import {EngineLib} from "./EngineLib.sol";

/// @dev All LayerZero V2 related routines
library LayerZeroUtils {
    uint32 internal constant CONFIG_TYPE_EXECUTOR = 1;
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    function setupLayerZeroConfig(EngineLib.ChainConfig memory src, uint32 dstEndpointId, bool setupBothWays) internal {
        // assume that fork and msg.sender are already correct

        if (src.sendLib != address(0)) {
            // Set send library for outbound messages
            ILayerZeroEndpointV2(src.endpoint)
                .setSendLibrary(
                    src.hostBridge, // OApp address
                    dstEndpointId, // Destination chain EID
                    src.sendLib // SendUln302 address
                );
        }

        // Set receive library for inbound messages
        if (setupBothWays) {
            ILayerZeroEndpointV2(src.endpoint)
                .setReceiveLibrary(
                    src.hostBridge, // OApp address
                    dstEndpointId, // Source chain EID
                    src.receiveLib, // ReceiveUln302 address
                    0 // Grace period for library switch
                );
        }
    }

    function setOsBridgePeers(Vm vm, EngineLib.ChainConfig memory src, EngineLib.ChainConfig memory dst) internal {
        // ------------------- Sonic: set up peer connection
        vm.selectFork(src.fork);

        vm.prank(src.multisig);
        IOAppCore(src.hostBridge).setPeer(dst.endpointId, bytes32(uint(uint160(address(dst.hostBridge)))));

        // ------------------- Avalanche: set up peer connection
        vm.selectFork(dst.fork);

        vm.prank(dst.multisig);
        IOAppCore(dst.hostBridge).setPeer(src.endpointId, bytes32(uint(uint160(address(src.hostBridge)))));
    }

    /// @notice Configures both ULN (DVN validators) and Executor for an OApp
    /// @param requiredDVNs  Array of DVN validator addresses
    /// @param confirmations  Minimum block confirmations
    function setSendConfig(
        EngineLib.ChainConfig memory src,
        uint32 dstEndpointId,
        address[] memory requiredDVNs,
        uint64 confirmations,
        uint32 maxMessageSize
    ) internal {
        // assume that fork and msg.sender are already correct

        // ---------------------- ULN (DVN) configuration ----------------------
        UlnConfig memory uln = UlnConfig({
            confirmations: confirmations,
            requiredDVNCount: uint8(requiredDVNs.length),
            optionalDVNCount: type(uint8).max,
            requiredDVNs: requiredDVNs, // sorted list of required DVN addresses
            optionalDVNs: new address[](0),
            optionalDVNThreshold: 0
        });

        ExecutorConfig memory exec = ExecutorConfig({
            maxMessageSize: maxMessageSize, // max bytes per cross-chain message
            executor: src.executor // address that pays destination execution fees
        });

        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);

        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam({eid: dstEndpointId, configType: CONFIG_TYPE_EXECUTOR, config: encodedExec});
        params[1] = SetConfigParam({eid: dstEndpointId, configType: CONFIG_TYPE_ULN, config: encodedUln});

        ILayerZeroEndpointV2(src.endpoint).setConfig(src.hostBridge, src.sendLib, params);
    }

    /// @notice Configures ULN (DVN validators) for on receiving chain
    /// @dev https://docs.layerzero.network/v2/developers/evm/configuration/dvn-executor-config
    /// @param requiredDVNs  Array of DVN validator addresses
    /// @param confirmations Minimum block confirmations for ULN
    function setReceiveConfig(
        EngineLib.ChainConfig memory src,
        uint32 dstEndpointId,
        address[] memory requiredDVNs,
        uint64 confirmations
    ) internal {
        // assume that fork and msg.sender are already correct

        // ---------------------- ULN (DVN) configuration ----------------------
        UlnConfig memory uln = UlnConfig({
            confirmations: confirmations, // Minimum block confirmations
            requiredDVNCount: uint8(requiredDVNs.length),
            optionalDVNCount: type(uint8).max,
            requiredDVNs: requiredDVNs, // sorted list of required DVN addresses
            optionalDVNs: new address[](0),
            optionalDVNThreshold: 0
        });

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({eid: dstEndpointId, configType: CONFIG_TYPE_ULN, config: abi.encode(uln)});

        ILayerZeroEndpointV2(src.endpoint).setConfig(src.hostBridge, src.receiveLib, params);
    }

    /// @notice Calls getConfig on the specified LayerZero Endpoint.
    /// @dev Decodes the returned bytes as a UlnConfig. Logs some of its fields.
    /// @dev https://docs.layerzero.network/v2/developers/evm/configuration/dvn-executor-config
    /// @param endpoint_ The LayerZero Endpoint address.
    /// @param oapp_ The address of your OApp.
    /// @param lib_ The address of the Message Library (send or receive).
    /// @param eid_ The remote endpoint identifier.
    /// @param configType_ The configuration type (1 = Executor, 2 = ULN).
    function getConfig(
        Vm vm,
        uint forkId,
        address endpoint_,
        address oapp_,
        address lib_,
        uint32 eid_,
        uint32 configType_
    ) internal {
        // Create a fork from the specified RPC URL.
        vm.selectFork(forkId);
        vm.startBroadcast();

        // Instantiate the LayerZero endpoint.
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(endpoint_);
        // Retrieve the raw configuration bytes.
        bytes memory config = endpoint.getConfig(oapp_, lib_, eid_, configType_);

        if (configType_ == 1) {
            // Decode the Executor config (configType = 1)
            ExecutorConfig memory execConfig = abi.decode(config, (ExecutorConfig));
            // Log some key configuration parameters.
            console.log("Executor maxMessageSize:", execConfig.maxMessageSize);
            console.log("Executor Address:", execConfig.executor);
        }

        if (configType_ == 2) {
            // Decode the ULN config (configType = 2)
            UlnConfig memory decodedConfig = abi.decode(config, (UlnConfig));
            // Log some key configuration parameters.
            console.log("Confirmations:", decodedConfig.confirmations);
            console.log("Required DVN Count:", decodedConfig.requiredDVNCount);
            for (uint i = 0; i < decodedConfig.requiredDVNs.length; i++) {
                console.logAddress(decodedConfig.requiredDVNs[i]);
            }
            console.log("Optional DVN Count:", decodedConfig.optionalDVNCount);
            for (uint i = 0; i < decodedConfig.optionalDVNs.length; i++) {
                console.logAddress(decodedConfig.optionalDVNs[i]);
            }
            console.log("Optional DVN Threshold:", decodedConfig.optionalDVNThreshold);
        }
        vm.stopBroadcast();
    }

    /// @notice Extract PacketSent message from emitted event
    function extractSendMessage(Vm.Log[] memory logs) internal pure returns (bytes memory message, bytes32 guid) {
        bytes memory encodedPayload;
        bytes32 sig = keccak256("PacketSent(bytes,bytes,address)"); // PacketSent(bytes encodedPayload, bytes options, address sendLibrary)

        for (uint i; i < logs.length; ++i) {
            if (logs[i].topics[0] == sig) {
                (encodedPayload,,) = abi.decode(logs[i].data, (bytes, bytes, address));
                break;
            }
        }

        // repeat decoding logic from Packet.sol\decode() and PacketV1Codec.sol\message()
        { // message = bytes(encodedPayload[113:]);

            // header length: 1 + 8 + 4 + 32 + 4 + 32 + 32 = 113
            uint start = 113;
            require(encodedPayload.length != 0, "payload not found");
            require(encodedPayload.length >= start, "encodedPayload too short");
            uint msgLen = encodedPayload.length - start;
            message = new bytes(msgLen);
            for (uint i = 0; i < msgLen; ++i) {
                message[i] = encodedPayload[start + i];
            }
        }

        assembly {
            guid := mload(add(encodedPayload, add(32, 81)))
        }
    }

    function extractPayload(Vm.Log[] memory logs) internal pure returns (bytes memory encodedPayload) {
        bytes32 sig = keccak256("PacketSent(bytes,bytes,address)"); // PacketSent(bytes encodedPayload, bytes options, address sendLibrary)

        for (uint i; i < logs.length; ++i) {
            if (logs[i].topics[0] == sig) {
                (encodedPayload,,) = abi.decode(logs[i].data, (bytes, bytes, address));
                break;
            }
        }

        return encodedPayload;
    }

    /// @notice Extract ComposeSent message from emitted event
    function extractComposeMessage(Vm
                .Log[] memory logs) internal pure returns (address from, address to, bytes memory message) {
        bytes32 sig = keccak256("ComposeSent(address,address,bytes32,uint16,bytes)"); // ComposeSent(address from, address to, bytes32 guid, uint16 index, bytes message)

        for (uint i; i < logs.length; ++i) {
            if (logs[i].topics[0] == sig) {
                (from, to,,, message) = abi.decode(logs[i].data, (address, address, bytes32, uint16, bytes));
                break;
            }
        }

        //        console.logBytes(message);
        return (from, to, message);
    }

    /// @notice Extract XTokenSent message from emitted event
    function extractXTokenSentMessage(Vm
                .Log[] memory logs)
        internal
        pure
        returns (
            address userFrom,
            uint32 dstEid,
            uint amount,
            uint amountSentLD,
            bytes32 guidId,
            uint64 nonce,
            uint nativeFee
        )
    {
        // event XTokenSent(address indexed userFrom, uint32 indexed dstEid, uint amount, uint amountSentLD, bytes32 indexed guidId, uint64 nonce, uint nativeFee);
        bytes32 sig = keccak256("XTokenSent(address,uint32,uint256,uint256,bytes32,uint64,uint256)");

        for (uint i; i < logs.length; ++i) {
            if (logs[i].topics[0] != sig) continue;

            // extract indexed out of topics
            // topics = [sig, userFrom, dstEid, guidId]
            require(logs[i].topics.length >= 4, "not enough topics for indexed params");
            userFrom = address(uint160(uint(logs[i].topics[1])));
            dstEid = uint32(uint(logs[i].topics[2]));
            guidId = bytes32(logs[i].topics[3]);

            // extract all other params from data: amount, amountSentLD, nonce, nativeFee
            require(logs[i].data.length >= 32 * 4, "data too short for non-indexed params");
            (amount, amountSentLD, nonce, nativeFee) = abi.decode(logs[i].data, (uint, uint, uint64, uint));
            break;
        }

        return (userFrom, dstEid, amount, amountSentLD, guidId, nonce, nativeFee);
    }
}
