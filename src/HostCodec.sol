// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDAOData} from "./interfaces/IDAOData.sol";
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
    function encode(IDAOData.DaoImages memory images, uint16 version) external pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoImages(images, version);
    }

    /// @inheritdoc IHostCodec
    function decodeImages(bytes memory encoded) external pure returns (IDAOData.DaoImages memory images) {
        return HostEncodingLib.decodeDaoImages(encoded);
    }

    /// @inheritdoc IHostCodec
    function encode(string[] memory socials) external pure returns (bytes memory) {
        return HostEncodingLib.encodeSocials(socials);
    }

    /// @inheritdoc IHostCodec
    function decodeSocials(bytes memory encoded) external pure returns (string[] memory socials) {
        return HostEncodingLib.decodeSocials(encoded);
    }

    /// @inheritdoc IHostCodec
    function encode(IDAOData.DaoNames memory data, uint16 version) external pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoNames(data, version);
    }

    /// @inheritdoc IHostCodec
    function decodeDaoNames(bytes memory encoded) external pure returns (IDAOData.DaoNames memory data) {
        return HostEncodingLib.decodeDaoNames(encoded);
    }

    /// @inheritdoc IHostCodec
    function encode(IDAOData.UnitDataInput[] memory units, uint16 version) external pure returns (bytes memory) {
        return HostEncodingLib.encodeUnits(units, version);
    }

    /// @inheritdoc IHostCodec
    function decodeUnits(bytes memory encoded) external pure returns (IDAOData.UnitDataInput[] memory units) {
        return HostEncodingLib.decodeUnits(encoded);
    }

    /// @inheritdoc IHostCodec
    function encode(IDAOData.UnitEmitData[] memory metadata, uint16 version) external pure returns (bytes memory) {
        return HostEncodingLib.encodeUnitsEmitData(metadata, version);
    }

    /// @inheritdoc IHostCodec
    function decodeUnitsEmitData(bytes memory encoded) external pure returns (IDAOData.UnitEmitData[] memory metadata) {
        return HostEncodingLib.decodeUnitsEmitData(encoded);
    }

    /// @inheritdoc IHostCodec
    function encode(IDAOData.Funding memory funding, uint16 version) external pure returns (bytes memory) {
        return HostEncodingLib.encodeFunding(funding, version);
    }

    /// @inheritdoc IHostCodec
    function decodeFunding(bytes memory encoded) external pure returns (IDAOData.Funding memory funding) {
        return HostEncodingLib.decodeFunding(encoded);
    }

    /// @inheritdoc IHostCodec
    function encode(IDAOData.Vesting[] memory vestings, uint16 version) external pure returns (bytes memory) {
        return HostEncodingLib.encodeVesting(vestings, version);
    }

    /// @inheritdoc IHostCodec
    function decodeVesting(bytes memory encoded) external pure returns (IDAOData.Vesting[] memory vestings) {
        return HostEncodingLib.decodeVesting(encoded);
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

    /// @inheritdoc IHostCodec
    function encode(IDAOData.DaoParameters memory data, uint16 version) external pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoParameters(data, version);
    }

    /// @inheritdoc IHostCodec
    function decodeDaoParameters(bytes memory encoded) external pure returns (IDAOData.DaoParameters memory) {
        return HostEncodingLib.decodeDaoParameters(encoded);
    }

    /// @inheritdoc IHostCodec
    function encode(IDAOData.DaoChainSettings memory data, uint16 version) external pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoChainSettings(data, version);
    }

    /// @inheritdoc IHostCodec
    function decodeDaoChainSettings(bytes memory encoded) external pure returns (IDAOData.DaoChainSettings memory) {
        return HostEncodingLib.decodeDaoChainSettings(encoded);
    }

    /// @inheritdoc IHostCodec
    function encode(
        uint16[] memory contractIndices,
        bytes32[] memory salt,
        uint16 version
    ) external pure returns (bytes memory) {
        return HostEncodingLib.encodeSalt(contractIndices, salt, version);
    }

    /// @inheritdoc IHostCodec
    function decodeSalt(bytes memory encoded)
        external
        pure
        returns (uint16[] memory contractIndices, bytes32[] memory salt)
    {
        return HostEncodingLib.decodeSalt(encoded);
    }

    /// @inheritdoc IHostCodec
    function encode(IDAOData.GovernanceSettings memory data, uint16 version) external pure returns (bytes memory) {
        return HostEncodingLib.encodeGovernanceSettings(data, version);
    }

    /// @inheritdoc IHostCodec
    function decodeGovernanceSettings(bytes memory encoded) external pure returns (IDAOData.GovernanceSettings memory) {
        return HostEncodingLib.decodeGovernanceSettings(encoded);
    }
}
