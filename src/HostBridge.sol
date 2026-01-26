// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {IHostBridge} from "./interfaces/IHostBridge.sol";
import {IHost} from "./interfaces/IHost.sol";
import {
    OAppUpgradeable,
    Origin,
    MessagingFee
} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {IHosted, Hosted} from "./base/Hosted.sol";
import {IHost} from "./interfaces/IHost.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Hosted} from "./base/Hosted.sol";

contract HostBridge is Hosted, OAppUpgradeable, IHostBridge {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @inheritdoc IHosted
    string public constant VERSION = "1.0.0";

    // keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostBridge")) - 1)) & ~bytes32(uint(0xff));
    bytes32 internal constant _HOST_BRIDGE_STORAGE_LOCATION =
        0x28a3e8e9ef264537f6f33b62bc141537ded5381f3a1c45a8310d293ea7607600;

    //region --------------------------------- Data types
    /// @custom:storage-location erc7201:stability.host-contracts.HostBridge
    struct HostBridgeStorage {
        /// @notice Address of the OS contract on the current chain
        address host;

        /// @notice Set of LayerZero endpoint IDs to which this bridge can send messages
        EnumerableSet.UintSet endpoints;

        /// @notice Gas limits for different message kinds
        mapping(uint messageKind => uint128 maxGasLimit) gasLimits;
    }

    //endregion --------------------------------- Data types

    //region --------------------------------- Initializers
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INITIALIZATION                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Initialize with Endpoint V2
    constructor(address lzEndpoint_) OAppUpgradeable(lzEndpoint_) {
        _disableInitializers();
    }

    /// @inheritdoc IHosted
    function initialize(address authority_, bytes memory payload) public payable initializer {
        (address _owner, address _delegate) = abi.decode(payload, (address, address));
        __Hosted_init(authority_);
        __OApp_init(_delegate == address(0) ? _owner : _delegate);
        __Ownable_init(_owner);
        console.log("Initialize HostBridge: authority_", authority_);
    }

    //endregion --------------------------------- Initializers

    //region --------------------------------- Views
    /// @inheritdoc IHostBridge
    function getHost() external view returns (address) {
        HostBridgeStorage storage $ = _getHostBridgeStorage();
        return $.host;
    }

    /// @inheritdoc IHostBridge
    function endpoints() external view returns (uint32[] memory) {
        HostBridgeStorage storage $ = _getHostBridgeStorage();
        uint len = $.endpoints.length();
        uint32[] memory result = new uint32[](len);
        for (uint i; i < len; ++i) {
            result[i] = uint32($.endpoints.at(i));
        }
        return result;
    }

    /// @inheritdoc IHostBridge
    function gasLimit(uint messageKind) external view returns (uint128) {
        HostBridgeStorage storage $ = _getHostBridgeStorage();
        return $.gasLimits[messageKind];
    }

    //endregion --------------------------------- Views

    //region --------------------------------- Actions
    /// @inheritdoc IHostBridge
    function setHost(address host_) external restricted {
        HostBridgeStorage storage $ = _getHostBridgeStorage();
        $.host = host_;

        emit SetHost(host_);
    }

    /// @inheritdoc IHostBridge
    function setGasLimit(uint messageKind, uint128 gasLimit_) external restricted {
        HostBridgeStorage storage $ = _getHostBridgeStorage();
        $.gasLimits[messageKind] = gasLimit_;

        emit SetGasLimit(messageKind, gasLimit_);
    }

    /// @inheritdoc IHostBridge
    function addEndpoint(uint32[] memory eids_) external restricted {
        HostBridgeStorage storage $ = _getHostBridgeStorage();

        uint len = eids_.length;
        for (uint i; i < len; ++i) {
            if ($.endpoints.add(uint(eids_[i]))) {
                emit AddEndpoint(eids_[i]);
            }
        }
    }

    /// @inheritdoc IHostBridge
    function removeEndpoint(uint32[] memory eids_) external restricted {
        HostBridgeStorage storage $ = _getHostBridgeStorage();

        uint len = eids_.length;
        for (uint i; i < len; ++i) {
            if ($.endpoints.remove(uint(eids_[i]))) {
                emit RemoveEndpoint(eids_[i]);
            }
        }
    }

    //endregion --------------------------------- Actions

    //region --------------------------------- IHostBridge
    /// @inheritdoc IHostBridge
    function quoteSendMessage(
        uint32 dstEid_,
        uint messageKind,
        bytes memory message_
    ) external view returns (uint fee) {
        HostBridgeStorage storage $ = _getHostBridgeStorage();

        uint128 _gasLimit = $.gasLimits[messageKind];
        bytes memory options = OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), _gasLimit, 0);

        return _quote(dstEid_, message_, options, false).nativeFee;
    }

    /// @inheritdoc IHostBridge
    function sendMessage(uint32 dstEid_, uint messageKind, bytes memory message_, uint fee) external restricted {
        HostBridgeStorage storage $ = _getHostBridgeStorage();

        uint128 _gasLimit = $.gasLimits[messageKind];
        bytes memory options = OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), _gasLimit, 0);
        MessagingFee memory _fee = MessagingFee({nativeFee: fee, lzTokenFee: 0});

        _lzSend(dstEid_, message_, options, _fee, payable(msg.sender));

        emit SendMessage(dstEid_, message_);
    }

    /// @inheritdoc IHostBridge
    function quoteSendMessageToAllChains(
        uint messageKind,
        bytes memory message_
    ) external view returns (uint totalFee) {
        HostBridgeStorage storage $ = _getHostBridgeStorage();

        uint128 _gasLimit = $.gasLimits[messageKind];
        bytes memory options = OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), _gasLimit, 0);

        uint len = $.endpoints.length();

        for (uint i; i < len; ++i) {
            uint32 dstEid = uint32($.endpoints.at(i));
            MessagingFee memory fee = _quote(dstEid, message_, options, false);
            totalFee += fee.nativeFee;
            console.log("fee", dstEid, fee.nativeFee, totalFee);
        }

        return totalFee;
    }

    /// @inheritdoc IHostBridge
    function sendMessageToAllChains(uint messageKind, bytes memory message_) external payable restricted {
        console.log("sendMessageToAllChains", msg.value);
        HostBridgeStorage storage $ = _getHostBridgeStorage();

        // todo assume here that gas limit is same for all chains
        // if it's not true max value should be set
        uint128 _gasLimit = $.gasLimits[messageKind];
        require(_gasLimit != 0, ZeroGasLimit(messageKind));

        bytes memory options = OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), _gasLimit, 0);

        uint len = $.endpoints.length();

        /// slither-disable-next-line uninitialized-local
        uint nativeSpent;

        for (uint i; i < len; ++i) {
            uint32 dstEid = uint32($.endpoints.at(i));
            console.log("i", i, dstEid);
            MessagingFee memory fee = _quote(dstEid, message_, options, false);

            nativeSpent += fee.nativeFee;
            require(nativeSpent <= msg.value, NotEnoughNative(msg.value));

            console.log("fee, value, spent", fee.nativeFee, msg.value, nativeSpent);

            _lzSend(dstEid, message_, options, fee, payable(msg.sender));

            emit SendMessage(dstEid, message_);
        }
    }

    //endregion --------------------------------- IHostBridge

    //region --------------------------------- Overrides
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Overrides                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev This QApp does not expect to receive messages
    function _lzReceive(
        Origin calldata origin_,
        bytes32 guid_,
        bytes calldata message_,
        address,
        /*_executor*/
        bytes calldata /*_extraData*/
    ) internal override {
        // ---------------------- check sender
        // struct Origin {uint32 srcEid; bytes32 sender; uint64 nonce;}
        // we don't need to check sender explicitly
        // assume that peers configuration doesn't allow untrusted senders (onlyPeer exception)
        // As soon as sendMessage is restricted to be called by OS only
        // nobody except OS can send messages to this contract.

        HostBridgeStorage storage $ = _getHostBridgeStorage();
        address receiver = $.host;

        if (receiver != address(0)) {
            IHost(receiver).onReceiveCrossChainMessage(origin_.srcEid, guid_, message_);
        }
    }

    /// @notice Override QAppSender._payNative to be able to send multiple LayerZero messages in a single transaction
    /// @dev Internal function to pay the native fee associated with the message.
    /// @param _nativeFee The native fee to be paid.
    /// @return nativeFee The amount of native currency paid.
    ///
    /// @dev If the OApp needs to initiate MULTIPLE LayerZero messages in a single transaction,
    /// this will need to be overridden because msg.value would contain multiple lzFees.
    function _payNative(uint _nativeFee) internal pure override returns (uint nativeFee) {
        // Assume that msg.value and nativeFee a checked in sendMessageToAllChains
        // if (msg.value != _nativeFee) revert NotEnoughNative(msg.value);

        return _nativeFee;
    }

    //endregion --------------------------------- Overrides

    //region --------------------------------- Internal logic
    function _getHostBridgeStorage() internal pure returns (HostBridgeStorage storage $) {
        bytes32 position = _HOST_BRIDGE_STORAGE_LOCATION;
        assembly {
            $.slot := position
        }
    }
    //endregion --------------------------------- Internal logic
}
