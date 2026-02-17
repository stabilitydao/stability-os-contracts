// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IBridgedActions} from "../interfaces/IBridgedActions.sol";
import {ISegment4} from "../interfaces/ISegment4.sol";

/// @notice Library for encoding and decoding proposal payloads
/// There are several uses cases for encoding/decoding:
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

    function encodeUnitsEmitData(
        IDAOData.UnitEmitData[] memory emitData,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            uint len = emitData.length;
            bytes[] memory items = new bytes[](len);
            for (uint i; i < len; ++i) {
                bytes memory pool = abi.encode(
                    emitData[i].pool.repos,
                    emitData[i].pool.label.name,
                    emitData[i].pool.label.description,
                    emitData[i].pool.label.color,
                    emitData[i].pool.contractorSymbol
                );
                bytes memory itemData1 = abi.encode(
                    emitData[i].name,
                    emitData[i].description,
                    uint8(emitData[i].status),
                    uint8(emitData[i].unitType),
                    emitData[i].revenueShare
                );
                bytes memory itemData2 = abi.encode(emitData[i].emoji, emitData[i].ui, emitData[i].api);
                items[i] = abi.encode(itemData1, itemData2, pool);
            }
            return abi.encode(version, items);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeUnitsEmitData(bytes memory payload) internal pure returns (IDAOData.UnitEmitData[] memory emitData) {
        {
            (uint16 version) = abi.decode(payload, (uint16));
            require(version == 1, IHost.UnsupportedStructVersion());
        }

        (, bytes[] memory item) = abi.decode(payload, (uint16, bytes[]));
        emitData = new IDAOData.UnitEmitData[](item.length);
        for (uint i; i < item.length; ++i) {
            bytes[3] memory data;
            (data[0], data[1], data[2]) = abi.decode(item[i], (bytes, bytes, bytes));

            {
                uint8 status;
                uint8 unitType;
                (emitData[i].name, emitData[i].description, status, unitType, emitData[i].revenueShare) =
                    abi.decode(data[0], (string, string, uint8, uint8, uint));
                emitData[i].status = ISegment4.UnitStatus(status);
                emitData[i].unitType = ISegment4.UnitType(unitType);
            }

            (emitData[i].emoji, emitData[i].ui, emitData[i].api) =
                abi.decode(data[1], (string, ISegment4.UnitUiLink[], string[]));

            (
                emitData[i].pool.repos,
                emitData[i].pool.label.name,
                emitData[i].pool.label.description,
                emitData[i].pool.label.color,
                emitData[i].pool.contractorSymbol
            ) = abi.decode(data[2], (string[], string, string, string, string));
        }
        return emitData;
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
                data.proposalThreshold,
                data.totalSupply
            );
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeDaoParameters(bytes memory payload) internal pure returns (ITokenomics.DaoParameters memory dest) {
        (uint16 version) = abi.decode(payload, (uint16));

        if (version == 1) {
            (
                ,
                dest.vePeriod,
                dest.pvpFee,
                dest.minPower,
                dest.ttBribe,
                dest.recoveryShare,
                dest.proposalThreshold,
                dest.totalSupply
            ) = abi.decode(payload, (uint16, uint32, uint16, uint, uint16, uint16, uint, uint));
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
            (, dest.bbRate) = abi.decode(payload, (uint16, uint8));
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
        uint16 bridgedAction_,
        uint32[] memory dstEids,
        bytes[] memory actionPayloads,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(version, bridgedAction_, dstEids, actionPayloads);
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

    /// @notice Encode BridgeDaoParams struct of the given version. Version is supported explicitly to simplify testing
    function encodeBridgeDaoParams(
        IBridgedActions.BridgeDaoParams memory data,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            bytes memory daoParameters = encodeDaoParameters(data.daoParameters, version);
            bytes memory chainSettings = encodeDaoChainSettings(data.chainSettings, version);
            bytes memory encodedData =
                abi.encode(data.symbol, data.name, data.unitIds, data.saltContractIndices, data.salts);
            return abi.encode(version, encodedData, daoParameters, chainSettings);
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
            (, bytes memory encodedData, bytes memory daoParameters, bytes memory chainSettings) =
                abi.decode(payload, (uint16, bytes, bytes, bytes));

            (data.symbol, data.name, data.unitIds, data.saltContractIndices, data.salts) =
                abi.decode(encodedData, (string, string, string[], uint16[], bytes32[]));
            data.daoParameters = decodeDaoParameters(daoParameters);
            data.chainSettings = decodeDaoChainSettings(chainSettings);
            return data;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    /// @notice Encode BridgedUnits struct of the given version. Version is supported explicitly to simplify testing
    function encodeBridgedUnits(
        IBridgedActions.BridgedUnits memory data,
        uint16 version
    ) internal pure returns (bytes memory) {
        if (version == 1) {
            return abi.encode(version, data.unitIds);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeBridgedUnits(bytes memory payload) internal pure returns (IBridgedActions.BridgedUnits memory data) {
        (uint16 version) = abi.decode(payload, (uint16));
        if (version == 1) {
            (, data.unitIds) = abi.decode(payload, (uint16, string[]));
            return data;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }
    //endregion ----------------------- Decode / Encode bridged-actions structs with versions

    //region ----------------------- Decode / Encode data without versions

    function decodeSocials(bytes memory payload) internal pure returns (string[] memory) {
        return abi.decode(payload, (string[]));
    }

    function encodeSocials(string[] memory data) internal pure returns (bytes memory) {
        return abi.encode(data);
    }

    //endregion ----------------------- Decode / Encode data without versions

    //region ----------------------- DaoDataInput for addLiveDao
    function encodeDaoDataInput(IDAOData.DaoDataInput memory dao) internal pure returns (bytes memory dest) {
        dest = abi.encode(dao.symbol, dao.name, uint8(dao.phase), dao.deployments);
        dest = abi.encode(dest, dao.chainSettings, dao.unitIds, dao.params);
        dest = abi.encode(dest, dao.socials, dao.activity, dao.images);
        dest = abi.encode(dest, dao.units, dao.funding, dao.vesting, dao.governanceSettings);
        dest = abi.encode(dest, dao.deployer, dao.metaDataLocation);
        uint len = dao.unitDataToEmit.length;
        bytes[] memory unitsMetaData = new bytes[](len);
        for (uint i; i < len; ++i) {
            unitsMetaData[i] = encodeUnitsMetaData(dao.unitDataToEmit[i]);
        }
        dest = abi.encode(dest, unitsMetaData);
    }

    function decodeDaoDataInput(bytes memory payload) internal pure returns (IDAOData.DaoDataInput memory dao) {
        bytes memory rest = payload;

        bytes[] memory unitsMetaDataEncoded;
        (rest, unitsMetaDataEncoded) = abi.decode(rest, (bytes, bytes[]));

        uint len = unitsMetaDataEncoded.length;
        dao.unitDataToEmit = new IDAOData.UnitEmitData[](len);
        for (uint i; i < len; ++i) {
            dao.unitDataToEmit[i] = decodeUnitsMetaData(unitsMetaDataEncoded[i]);
        }

        (rest, dao.deployer, dao.metaDataLocation) = abi.decode(rest, (bytes, address, string));

        (rest, dao.units, dao.funding, dao.vesting, dao.governanceSettings) = abi.decode(
            rest,
            (
                bytes,
                IDAOData.UnitDataInput[],
                ITokenomics.Funding[],
                ITokenomics.Vesting[],
                ITokenomics.GovernanceSettings
            )
        );

        (rest, dao.socials, dao.activity, dao.images) =
            abi.decode(rest, (bytes, string[], ITokenomics.Activity[], ITokenomics.DaoImages));

        (rest, dao.chainSettings, dao.unitIds, dao.params) =
            abi.decode(rest, (bytes, ITokenomics.DaoChainSettings, string[], ITokenomics.DaoParameters));

        {
            uint8 phase;
            (dao.symbol, dao.name, phase, dao.deployments) =
                abi.decode(rest, (string, string, uint8, ITokenomics.DaoDeploymentInfo));
            dao.phase = ITokenomics.LifecyclePhase(phase);
        }

        return dao;
    }

    function encodeUnitsMetaData(IDAOData.UnitEmitData memory data) internal pure returns (bytes memory dest) {
        dest = abi.encode(data.name, data.description, uint8(data.status), data.unitType, data.revenueShare, data.emoji);
        uint len = data.ui.length;
        bytes[] memory ui = new bytes[](len);
        for (uint i; i < len; ++i) {
            ui[i] = abi.encode(data.ui[i].href, data.ui[i].title);
        }
        dest = abi.encode(
            dest,
            ui,
            data.api,
            data.pool.repos,
            data.pool.label.name,
            data.pool.label.description,
            data.pool.label.color,
            data.pool.contractorSymbol
        );
    }

    function decodeUnitsMetaData(bytes memory payload) internal pure returns (IDAOData.UnitEmitData memory data) {
        bytes memory rest = payload;

        bytes[] memory uiEncoded;
        (
            rest,
            uiEncoded,
            data.api,
            data.pool.repos,
            data.pool.label.name,
            data.pool.label.description,
            data.pool.label.color,
            data.pool.contractorSymbol
        ) = abi.decode(rest, (bytes, bytes[], string[], string[], string, string, string, string));

        uint len = uiEncoded.length;
        data.ui = new ISegment4.UnitUiLink[](len);
        for (uint i; i < len; ++i) {
            (data.ui[i].href, data.ui[i].title) = abi.decode(uiEncoded[i], (string, string));
        }

        {
            uint8 status;
            uint8 unitType;
            (data.name, data.description, status, unitType, data.revenueShare, data.emoji) =
                abi.decode(rest, (string, string, uint8, uint8, uint, string));
            data.status = ISegment4.UnitStatus(status);
            data.unitType = ISegment4.UnitType(unitType);
        }

        return data;
    }

    //endregion ----------------------- DaoDataInput for addLiveDao

    //region ----------------------- Decode / Encode data for data reader
    function encodeDAOData(IDAOData.DaoData memory data, uint16 version) internal pure returns (bytes memory dest) {
        if (version == 1) {
            // --- enum[] -> uint8[] ---
            uint len = data.activity.length;
            uint8[] memory activityRaw = new uint8[](len);
            for (uint i; i < len; ++i) {
                activityRaw[i] = uint8(data.activity[i]);
            }

            bytes[6] memory b;
            b[0] = abi.encode(data.symbol, data.uid, data.name, uint8(data.phase), data.deployments);
            b[1] = abi.encode(data.chainSettings, data.unitIds, data.unitRevenue, data.unitRevenueAssets);
            b[2] = abi.encode(data.params, data.initialChain, data.socials);
            b[3] = abi.encode(activityRaw, data.images, data.units, data.funding, data.vesting);
            b[4] = abi.encode(
                data.governanceSettings, data.deployer, data.saltContractIndices, data.salts, data.metaDataLocation
            );
            b[5] = abi.encode(data.vestingContracts);

            dest = abi.encode(version, b);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeDAOData(bytes memory payload) internal pure returns (IDAOData.DaoData memory dest) {
        (uint16 version) = abi.decode(payload, (uint16));

        if (version == 1) {
            (, bytes[6] memory b) = abi.decode(payload, (uint16, bytes[6]));

            {
                uint8 phaseRaw;

                (dest.symbol, dest.uid, dest.name, phaseRaw, dest.deployments) =
                    abi.decode(b[0], (string, uint, string, uint8, ITokenomics.DaoDeploymentInfo));

                dest.phase = ITokenomics.LifecyclePhase(phaseRaw);
            }

            (dest.chainSettings, dest.unitIds, dest.unitRevenue, dest.unitRevenueAssets) =
                abi.decode(b[1], (ITokenomics.DaoChainSettings, string[], uint[], address[]));

            (dest.params, dest.initialChain, dest.socials) =
                abi.decode(b[2], (ITokenomics.DaoParameters, uint, string[]));

            {
                uint8[] memory activityRaw;

                (activityRaw, dest.images, dest.units, dest.funding, dest.vesting) = abi.decode(
                    b[3],
                    (
                        uint8[],
                        ITokenomics.DaoImages,
                        ITokenomics.UnitData[],
                        ITokenomics.Funding[],
                        ITokenomics.Vesting[]
                    )
                );

                uint len = activityRaw.length;
                dest.activity = new ITokenomics.Activity[](len);
                for (uint i; i < len; ++i) {
                    dest.activity[i] = ITokenomics.Activity(activityRaw[i]);
                }
            }

            (dest.governanceSettings, dest.deployer, dest.saltContractIndices, dest.salts, dest.metaDataLocation) =
                abi.decode(b[4], (ITokenomics.GovernanceSettings, address, uint16[], bytes32[], string));

            (dest.vestingContracts) = abi.decode(b[5], (address[]));

            return dest;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function encodeProposal(
        ITokenomics.Proposal memory data,
        uint16 version
    ) internal pure returns (bytes memory dest) {
        if (version == 1) {
            bytes memory b1 = abi.encode(
                data.action, data.validationRequired, data.votingRequired, data.validationStatus, data.id
            );
            bytes memory b2 = abi.encode(data.symbol, data.created, data.status, data.payloadHash);
            return abi.encode(version, b1, b2);
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    function decodeProposal(bytes memory payload) internal pure returns (ITokenomics.Proposal memory dest) {
        (uint16 version) = abi.decode(payload, (uint16));
        if (version == 1) {
            (, bytes memory b1, bytes memory b2) = abi.decode(payload, (uint16, bytes, bytes));
            {
                uint8 action;
                uint8 validationStatus;
                (action, dest.validationRequired, dest.votingRequired, validationStatus, dest.id) =
                    abi.decode(b1, (uint8, bool, bool, uint8, bytes32));
                dest.action = ITokenomics.DAOAction(action);
                dest.validationStatus = ITokenomics.ValidationStatus(validationStatus);
            }

            {
                uint8 status;
                (dest.symbol, dest.created, status, dest.payloadHash) = abi.decode(b2, (string, uint64, uint8, bytes32));
                dest.status = ITokenomics.VotingStatus(status);
            }

            return dest;
        } else {
            revert IHost.UnsupportedStructVersion();
        }
    }

    //endregion ----------------------- Decode / Encode data for data reader
}

