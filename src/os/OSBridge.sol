// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IOSBridge} from "../interfaces/IOSBridge.sol";
import {IOS} from "../interfaces/IOS.sol";
import {
    OAppUpgradeable,
    Origin,
    MessagingFee
} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {IControllable2, Controllable2} from "../core/base/Controllable2.sol";
import {IOS} from "../interfaces/IOS.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Controllable2} from "../core/base/Controllable2.sol";

contract OSBridge is Controllable2, OAppUpgradeable, IOSBridge {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @inheritdoc IControllable2
    string public constant VERSION = "1.0.0";

    // keccak256(abi.encode(uint(keccak256("erc7201:stability-os-contracts.OSBridge")) - 1)) & ~bytes32(uint(0xff));
    bytes32 internal constant _OS_BRIDGE_STORAGE_LOCATION = 0; // todo

    //region --------------------------------- Data types
    /// @custom:storage-location erc7201:stability-os-contracts.OSBridge
    struct OsBridgeStorage {
        /// @notice Address of the OS contract on the current chain
        address os;

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

    /// @inheritdoc IControllable2
    function initialize(address authority_, bytes memory payload) public initializer {
        (address _owner, address _delegate) = abi.decode(payload, (address, address));
        __Controllable_init(authority_);
        __OApp_init(_delegate == address(0) ? _owner : _delegate);
        __Ownable_init(_owner);
    }

    //endregion --------------------------------- Initializers

    //region --------------------------------- Views
    /// @inheritdoc IOSBridge
    function getOs() external view returns (address) {
        OsBridgeStorage storage $ = _getOsBridgeStorage();
        return $.os;
    }

    /// @inheritdoc IOSBridge
    function endpoints() external view returns (uint32[] memory) {
        OsBridgeStorage storage $ = _getOsBridgeStorage();
        uint len = $.endpoints.length();
        uint32[] memory result = new uint32[](len);
        for (uint i; i < len; ++i) {
            result[i] = uint32($.endpoints.at(i));
        }
        return result;
    }

    /// @inheritdoc IOSBridge
    function gasLimit(uint messageKind) external view returns (uint128) {
        OsBridgeStorage storage $ = _getOsBridgeStorage();
        return $.gasLimits[messageKind];
    }

    //endregion --------------------------------- Views

    //region --------------------------------- Actions
    /// @inheritdoc IOSBridge
    function setOs(address os_) external restricted {
        OsBridgeStorage storage $ = _getOsBridgeStorage();
        $.os = os_;

        emit SetOs(os_);
    }

    /// @inheritdoc IOSBridge
    function setGasLimit(uint messageKind, uint128 gasLimit_) external restricted {
        OsBridgeStorage storage $ = _getOsBridgeStorage();
        $.gasLimits[messageKind] = gasLimit_;

        emit SetGasLimit(messageKind, gasLimit_);
    }

    /// @inheritdoc IOSBridge
    function addEndpoint(uint32[] memory eids_) external restricted {
        OsBridgeStorage storage $ = _getOsBridgeStorage();

        uint len = eids_.length;
        for (uint i; i < len; ++i) {
            if ($.endpoints.add(uint(eids_[i]))) {
                emit AddEndpoint(eids_[i]);
            }
        }
    }

    /// @inheritdoc IOSBridge
    function removeEndpoint(uint32[] memory eids_) external restricted {
        OsBridgeStorage storage $ = _getOsBridgeStorage();

        uint len = eids_.length;
        for (uint i; i < len; ++i) {
            if ($.endpoints.remove(uint(eids_[i]))) {
                emit RemoveEndpoint(eids_[i]);
            }
        }
    }

    //endregion --------------------------------- Actions

    //region --------------------------------- IOSBridge
    /// @inheritdoc IOSBridge
    function quoteSendMessage(
        uint32 dstEid_,
        bytes memory options_,
        bytes memory message_
    ) external view returns (MessagingFee memory fee) {
        return _quote(dstEid_, message_, options_, false);
    }

    /// @inheritdoc IOSBridge
    function sendMessage(
        uint32 dstEid_,
        bytes memory options_,
        bytes memory message_,
        MessagingFee memory fee_
    ) external restricted {
        // this function is restricted to be called by OS only
        // the restriction is checked by AccessManager

        _lzSend(dstEid_, message_, options_, fee_, payable(msg.sender));

        emit SendMessage(dstEid_, message_);
    }

    /// @inheritdoc IOSBridge
    function sendMessageToAllChains(uint messageKind, bytes memory message_) external {
        OsBridgeStorage storage $ = _getOsBridgeStorage();

        uint128 _gasLimit = $.gasLimits[messageKind];
        require(_gasLimit != 0, UnsupportedMessageKind(messageKind));

        bytes memory options = OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), _gasLimit, 0);

        uint len = $.endpoints.length();

        for (uint i; i < len; ++i) {
            uint32 dstEid = uint32($.endpoints.at(i));
            MessagingFee memory fee = _quote(dstEid, message_, options, false);
            _lzSend(dstEid, message_, options, fee, payable(msg.sender));

            emit SendMessage(dstEid, message_);
        }
    }

    //endregion --------------------------------- IOSBridge

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

        OsBridgeStorage storage $ = _getOsBridgeStorage();
        address receiver = $.os;

        IOS(receiver).onReceiveCrossChainMessage(origin_.srcEid, guid_, message_);
    }

    //endregion --------------------------------- Overrides

    //region --------------------------------- Internal logic
    function _getOsBridgeStorage() internal pure returns (OsBridgeStorage storage $) {
        bytes32 position = _OS_BRIDGE_STORAGE_LOCATION;
        assembly {
            $.slot := position
        }
    }
    //endregion --------------------------------- Internal logic
}
