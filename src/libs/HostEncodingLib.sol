// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IBridgedActions} from "../interfaces/IBridgedActions.sol";
import {IDAOMetadata} from "../interfaces/IDAOMetadata.sol";

/// @notice Library for encoding and decoding proposal payloads
/// Tokenomic uses some structs.
/// The structs are stored as payload and emitted in events.
/// After voting these payloads can be passed to update functions.
/// New fields can be added to the structs in future versions at any moment.
/// The library allows to decode structs of any version (old or current) correctly at any time.
library HostEncodingLib {
    //region ----------------------- Versions of the structs

    /// @notice Version of payload encoding API. Each payload contain version that were used to encode it.
    /// Payloads are emitted and can be used at the moment when current version of API is updated.
    /// Decode functions must support all previous versions of the structs.
    uint16 public constant PAYLOAD_API_VERSION = 1;

    //endregion ----------------------- Versions of the structs

    //region ----------------------- Decode / Encode update-actions structs with versions

    /// @notice Encode DaoImages struct of the given version. Version is supported explicitly to simplify testing
    function encodeDaoImages(ITokenomics.DaoImages memory data, uint16 version) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(version, data.seedToken, data.tgeToken, data.token, data.xToken, data.daoToken);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeDaoImages(bytes memory payload) internal pure returns (ITokenomics.DaoImages memory dest) {
        (uint16 version) = abi.decode(payload, (uint16));
        if (version == 1) {
            (, dest.seedToken, dest.tgeToken, dest.token, dest.xToken, dest.daoToken) =
                abi.decode(payload, (uint16, string, string, string, string, string));
            return dest;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    /// @notice Encode array of UnitInfo of the given version. Version is supported explicitly to simplify testing
    function encodeUnits(
        IDAOData.UnitDataInput[] memory data,
        uint16 version
    ) internal pure returns (bytes memory payload) {
        if (version == 1) {
            return abi.encode(version, data);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeUnits(bytes memory payload) internal pure returns (IDAOData.UnitDataInput[] memory dest) {
        (uint16 version) = abi.decode(payload, (uint16));
        if (version == 1) {
            // if new version of UnitInfo will be created it's necessary to do following:
            // 1) create a copy of old structure UnitInfoV1
            // 2) replace ITokenomics.UnitInfo by UnitInfoV1 below
            // 3) create a branch of code for version == 2 below
            (version, dest) = abi.decode(payload, (uint16, IDAOData.UnitDataInput[]));
            return dest;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function encodeUnitsMetadata(
        IDAOData.UnitMetaData[] memory unitsMetadata,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            uint len = unitsMetadata.length;
            bytes[] memory items = new bytes[](len);
            for (uint i; i < len; ++i) {
                items[i] = abi.encode(
                    unitsMetadata[i].name,
                    uint8(unitsMetadata[i].status),
                    unitsMetadata[i].unitType,
                    unitsMetadata[i].revenueShare,
                    unitsMetadata[i].emoji,
                    unitsMetadata[i].ui,
                    unitsMetadata[i].api
                );
            }
            return abi.encode(version, items);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeUnitsMetadata(bytes memory payload)
        internal
        pure
        returns (IDAOData.UnitMetaData[] memory unitsMetadata)
    {
        {
            (uint16 version) = abi.decode(payload, (uint16));
            require(version == 1, IHost.UnsupportedStructVersion());
        }

        (, bytes[] memory item) = abi.decode(payload, (uint16, bytes[]));
        unitsMetadata = new IDAOData.UnitMetaData[](item.length);
        for (uint i; i < item.length; ++i) {
            uint8 status;
            (
                unitsMetadata[i].name,
                status,
                unitsMetadata[i].unitType,
                unitsMetadata[i].revenueShare,
                unitsMetadata[i].emoji,
                unitsMetadata[i].ui,
                unitsMetadata[i].api
            ) = abi.decode(item[i], (string, uint8, uint16, uint, string, IDAOMetadata.UnitUiLink[], string[]));

            unitsMetadata[i].status = IDAOMetadata.UnitStatus(status);
        }
        return unitsMetadata;
    }

    /// @notice Encode Funding struct of the given version. Version is supported explicitly to simplify testing
    function encodeFunding(ITokenomics.Funding memory data, uint16 version) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(
                version, data.fundingType, data.start, data.end, data.minRaise, data.maxRaise, data.raised, data.claim
            );
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeFunding(bytes memory payload) internal pure returns (ITokenomics.Funding memory dest) {
        (uint16 version) = abi.decode(payload, (uint16));
        if (version == 1) {
            (, dest.fundingType, dest.start, dest.end, dest.minRaise, dest.maxRaise, dest.raised, dest.claim) =
                abi.decode(payload, (uint16, ITokenomics.FundingType, uint64, uint64, uint, uint, uint, uint));
            return dest;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    /// @notice Encode array of Vesting of the given version. Version is supported explicitly to simplify testing
    function encodeVesting(ITokenomics.Vesting[] memory data, uint16 version) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(version, data);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeVesting(bytes memory payload) internal pure returns (ITokenomics.Vesting[] memory dest) {
        (uint16 version) = abi.decode(payload, (uint16));

        if (version == 1) {
            // if new version of Vesting will be created it's necessary to do following:
            // 1) create a copy of old structure VestingV1
            // 2) replace ITokenomics.Vesting by VestingV1 below
            // 3) create a branch of code for version == 2 below
            (version, dest) = abi.decode(payload, (uint16, ITokenomics.Vesting[]));
            return dest;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    /// @notice Encode DaoParameters struct of the given version. Version is supported explicitly to simplify testing
    function encodeDaoParameters(
        ITokenomics.DaoParameters memory data,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(
                version,
                data.vePeriod,
                data.pvpFee,
                data.minPower,
                data.ttBribe,
                data.recoveryShare,
                data.proposalThreshold
            );
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeDaoParameters(bytes memory payload) internal pure returns (ITokenomics.DaoParameters memory dest) {
        (uint16 version) = abi.decode(payload, (uint16));

        if (version == 1) {
            (, dest.vePeriod, dest.pvpFee, dest.minPower, dest.ttBribe, dest.recoveryShare, dest.proposalThreshold) =
                abi.decode(payload, (uint16, uint32, uint16, uint, uint16, uint16, uint));
            return dest;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    /// @notice Encode DaoParameters struct of the given version. Version is supported explicitly to simplify testing
    function encodeDaoChainSettings(
        ITokenomics.DaoChainSettings memory data,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(version, data.bbRate);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeDaoChainSettings(bytes memory payload)
        internal
        pure
        returns (ITokenomics.DaoChainSettings memory dest)
    {
        (uint16 version) = abi.decode(payload, (uint16));

        if (version == 1) {
            (, dest.bbRate) = abi.decode(payload, (uint16, uint));
            return dest;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function encodeDaoNames(ITokenomics.DaoNames memory data, uint16 version) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(version, data.name, data.symbol);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeDaoNames(bytes memory payload) internal pure returns (ITokenomics.DaoNames memory dest) {
        (uint16 version) = abi.decode(payload, (uint16));

        if (version == 1) {
            (, dest.name, dest.symbol) = abi.decode(payload, (uint16, string, string));
            return dest;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function encodeSalt(
        uint16[] memory contractIndices,
        bytes32[] memory salt,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(version, contractIndices, salt);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeSalt(bytes memory payload)
        internal
        pure
        returns (uint16[] memory contractIndices, bytes32[] memory salt)
    {
        (uint16 version) = abi.decode(payload, (uint16));

        if (version == 1) {
            (, contractIndices, salt) = abi.decode(payload, (uint16, uint16[], bytes32[]));
            return (contractIndices, salt);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function encodeBridgedAction(
        uint16 actionKind,
        uint32[] memory dstEids,
        bytes[] memory actionPayloads,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(version, actionKind, dstEids, actionPayloads);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeBridgedAction(bytes memory payload)
        internal
        pure
        returns (uint16 actionKind, uint32[] memory dstEids, bytes[] memory actionPayloads)
    {
        (uint16 version) = abi.decode(payload, (uint16));

        if (version == 1) {
            (, actionKind, dstEids, actionPayloads) = abi.decode(payload, (uint16, uint16, uint32[], bytes[]));
            return (actionKind, dstEids, actionPayloads);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    //endregion ----------------------- Decode / Encode update-actions structs with versions

    //region ----------------------- Decode / Encode bridged-actions structs with versions

    //endregion ----------------------- Decode / Encode bridged-actions structs with versions
    /// @notice Encode BridgeDaoParams struct of the given version. Version is supported explicitly to simplify testing
    function encodeBridgeDaoParams(
        IBridgedActions.BridgeDaoParams memory data,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            bytes memory daoParameters = encodeDaoParameters(data.daoParameters, version);
            bytes memory chainSettings = encodeDaoChainSettings(data.chainSettings, version);
            return abi.encode(
                version,
                data.symbol,
                data.name,
                data.unitIds,
                daoParameters,
                chainSettings,
                data.saltContractIndices,
                data.salts
            );
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeBridgeDaoParams(bytes memory payload)
        internal
        pure
        returns (IBridgedActions.BridgeDaoParams memory data)
    {
        (uint16 version) = abi.decode(payload, (uint16));
        if (version == 1) {
            bytes memory daoParameters;
            bytes memory chainSettings;
            (
                version,
                data.symbol,
                data.name,
                data.unitIds,
                daoParameters,
                chainSettings,
                data.saltContractIndices,
                data.salts
            ) = abi.decode(payload, (uint16, string, string, string[], bytes, bytes, uint16[], bytes32[]));
            data.daoParameters = decodeDaoParameters(daoParameters);
            data.chainSettings = decodeDaoChainSettings(chainSettings);
            return data;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }
    //region ----------------------- Decode / Encode data without versions

    function decodeSocials(bytes memory payload) internal pure returns (string[] memory) {
        return abi.decode(payload, (string[]));
    }

    function encodeSocials(string[] memory data) internal pure returns (bytes memory) {
        return abi.encode(data);
    }

    //endregion ----------------------- Decode / Encode data without versions
}
