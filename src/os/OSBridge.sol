// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IOSBridge} from "../interfaces/IOSBridge.sol";
import {
OAppUpgradeable,
Origin,
MessagingFee
} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {IControllable2, Controllable2} from "../core/base/Controllable2.sol";

contract OSBridge is Controllable2, OAppUpgradeable, IOSBridge {

    /// @inheritdoc IControllable2
    string public constant VERSION = "1.0.0";

    // keccak256(abi.encode(uint(keccak256("erc7201:stability-os-contracts.OSBridge")) - 1)) & ~bytes32(uint(0xff));
    bytes32 internal constant _OS_BRIDGE_STORAGE_LOCATION = 0; // todo

    //region --------------------------------- Initializers
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INITIALIZATION                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Initialize with Endpoint V2
    constructor(address lzEndpoint_) OAppUpgradeable(lzEndpoint_) {
        _disableInitializers();
    }

    function initialize(address authority_) public initializer {
        // todo
    }

    /// todo
    function initialize(address authority_, address owner_, address delegate_) public initializer {
        __Controllable_init(authority_);
        __OApp_init(delegate_ == address(0) ? owner_ : delegate_);
        __Ownable_init(owner_);
    }

    //endregion --------------------------------- Initializers

    //region --------------------------------- IOSBridge
    /// @inheritdoc IOSBridge
    function quoteSendMessage(uint32 dstEid_, bytes memory options_, bytes memory message_) external view returns (MessagingFee memory fee) {
        return _quote(dstEid_, message_, options_, false);
    }

    /// @inheritdoc IOSBridge
    function sendMessage(uint32 dstEid_, bytes memory options_, bytes memory message_, MessagingFee memory fee_) external restricted {
        // this function is restricted to be called by OS only
        // the restriction is checked by AccessManager

        _lzSend(dstEid_, message_, options_, fee_, payable(msg.sender));

        emit SendMessage(dstEid_, message_);
    }

    //endregion --------------------------------- IOSBridge

    //region --------------------------------- Overrides
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Overrides                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev This QApp does not expect to receive messages
    function _lzReceive(
        Origin calldata,
    /*_origin*/
        bytes32,
    /*_guid*/
        bytes calldata,
    /*_message*/
        address,
    /*_executor*/
        bytes calldata /*_extraData*/
    ) internal pure override {
        // ---------------------- check sender
        // struct Origin {uint32 srcEid; bytes32 sender; uint64 nonce;}
        // we don't need to check sender explicitly
        // assume that peers configuration doesn't allow untrusted senders (onlyPeer exception)

        // todo receiver ?
    }

    //endregion --------------------------------- Overrides
}