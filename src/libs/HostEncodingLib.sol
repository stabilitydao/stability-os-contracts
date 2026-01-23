// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {IHost} from "../interfaces/IHost.sol";

/// @notice Library for encoding and decoding proposal payloads
/// Tokenomic uses some structs.
/// The structs are stored as payload in proposals.
/// New fields can be added to the structs in future versions at any moment.
/// The library allows to decode structs of any version (old or current) correctly at any time.
library HostEncodingLib {
    //region ----------------------- Versions of the structs
    
    /// @notice Version of payload encoding API. Each payload contain version that were used to encode it.
    /// Payloads are emitted and can be used at the moment when current version of API is updated.
    /// Decode functions must support all previous versions of the structs.
    uint16 public constant PAYLOAD_API_VERSION = 1;

    //endregion ----------------------- Versions of the structs

    //region ----------------------- Decode / Encode structs with versions

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
        uint chainId,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(version, chainId, contractIndices, salt);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeSalt(bytes memory payload)
        internal
        pure
        returns (uint16[] memory contractIndices, bytes32[] memory salt, uint chainId)
    {
        (uint16 version) = abi.decode(payload, (uint16));

        if (version == 1) {
            (, chainId, contractIndices, salt) = abi.decode(payload, (uint16, uint, uint16[], bytes32[]));
            return (contractIndices, salt, chainId);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }
    //endregion ----------------------- Decode / Encode structs with versions

    //region ----------------------- Decode / Encode data without versions

    function decodeSocials(bytes memory payload) internal pure returns (string[] memory) {
        return abi.decode(payload, (string[]));
    }

    function encodeSocials(string[] memory data) internal pure returns (bytes memory) {
        return abi.encode(data);
    }

    //endregion ----------------------- Decode / Encode data without versions
}
