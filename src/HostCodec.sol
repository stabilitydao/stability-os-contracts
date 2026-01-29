// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

//import {ITokenomics} from "./interfaces/ITokenomics.sol";
//import {IDAOData} from "./interfaces/IDAOData.sol";
import {IHostCodec} from "./interfaces/IHostCodec.sol";
import {IBridgedActions} from "./interfaces/IBridgedActions.sol";
import {Hosted} from "./base/Hosted.sol";
import {IHosted} from "./interfaces/IHosted.sol";
import {HostEncodingLib} from "./libs/HostEncodingLib.sol";

/// @notice Allow to create DAO and update its state according to life cycle
/// [META-ISSUE] DAO must manage properties itself via voting by executing Operating proposals.
contract HostCodec is IHostCodec, Hosted {
    /// @inheritdoc IHosted
    string public constant VERSION = "1.0.0";

    /// @inheritdoc IHosted
    function initialize(address authority_, bytes memory) public payable initializer {
        __Hosted_init(authority_);
    }

    /// @inheritdoc IHostCodec
    function PAYLOAD_API_VERSION() external pure returns (uint16) {
        return HostEncodingLib.PAYLOAD_API_VERSION;
    }

    /// @inheritdoc IHostCodec
    function encode(IBridgedActions.BridgeDaoParams memory data, uint16 version) external pure returns (bytes memory) {
        return HostEncodingLib.encodeBridgeDaoParams(data, version);
    }

    /// @inheritdoc IHostCodec
    function decodeBridgeDaoParams(bytes memory encoded)
        external
        pure
        returns (IBridgedActions.BridgeDaoParams memory)
    {
        return HostEncodingLib.decodeBridgeDaoParams(encoded);
    }
}
