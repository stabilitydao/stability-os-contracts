// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SampleDataLib} from "../utils/SampleDataLib.sol";
import {Test} from "forge-std/Test.sol";
import {HostEncodingLib} from "../../src/libs/HostEncodingLib.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IBridgedActions} from "../../src/interfaces/IBridgedActions.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";
import {ISegment4} from "../../src/interfaces/ISegment4.sol";
import {HostUtilsLib} from "../utils/HostUtilsLib.sol";

contract HostEncodingLibTest is Test {
    uint8 private constant INCORRECT_VERSION = 255;

    //region -------------------------------------- Tests for encoding/decoding of structs
    function testEncodeDaoImages() public pure {
        IDAOData.DaoImages memory a = SampleDataLib.getDaoImages();

        bytes memory encA = HostEncodingLib.encodeDaoImages(a, 1);

        IDAOData.DaoImages memory decA = HostEncodingLib.decodeDaoImages(encA);

        assertEq(decA.seedToken, a.seedToken);
        assertEq(decA.tgeToken, a.tgeToken);
        assertEq(decA.token, a.token);
        assertEq(decA.xToken, a.xToken);
        assertEq(decA.daoToken, a.daoToken);
    }

    function testEncodeDaoImages_IncorrectVersion_Revert() public {
        IDAOData.DaoImages memory a = SampleDataLib.getDaoImages();

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._encodeDaoImagesWrapper(a, INCORRECT_VERSION);

        bytes memory payloadUnknownVersion =
            abi.encode(INCORRECT_VERSION, a.seedToken, a.tgeToken, a.token, a.xToken, a.daoToken);

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._decodeDaoImagesWrapper(payloadUnknownVersion);
    }

    function testEncodeFunding() public view {
        IDAOData.Funding memory a;
        a.fundingType = IDAOData.FundingType.SEED_0;
        a.start = 100;
        a.end = 200;
        a.minRaise = 1000;
        a.maxRaise = 5000;
        a.raised = 250;
        a.claim = 1;

        bytes memory encA = this._encodeFundingWrapper(a, 1);

        IDAOData.Funding memory decA = this._decodeFundingWrapper(encA);

        assertEq(uint8(decA.fundingType), uint8(a.fundingType));
        assertEq(uint64(decA.start), uint64(a.start));
        assertEq(uint64(decA.end), uint64(a.end));
        assertEq(decA.minRaise, a.minRaise);
        assertEq(decA.maxRaise, a.maxRaise);
        assertEq(decA.raised, a.raised);
        assertEq(decA.claim, a.claim);
    }

    function testEncodeFunding_IncorrectVersion_Revert() public {
        IDAOData.Funding memory a;
        a.fundingType = IDAOData.FundingType(uint8(0));
        a.start = 100;
        a.end = 200;
        a.minRaise = 1000;
        a.maxRaise = 5000;
        a.raised = 250;
        a.claim = 1;

        // encode should revert for unsupported version (library checks version on encode)
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._encodeFundingWrapper(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion =
            abi.encode(INCORRECT_VERSION, a.fundingType, a.start, a.end, a.minRaise, a.maxRaise, a.raised, a.claim);

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._decodeFundingWrapper(payloadUnknownVersion);
    }

    function testEncodeVesting() public view {
        IDAOData.Vesting[] memory a = new IDAOData.Vesting[](1);
        IDAOData.Vesting[] memory b = new IDAOData.Vesting[](2);
        IDAOData.Vesting[] memory c = new IDAOData.Vesting[](0);

        a[0] = IDAOData.Vesting({name: "Team", description: "team vesting", allocation: 1000, start: 1, end: 100});
        b[0] = IDAOData.Vesting({name: "Seed", description: "seed vesting", allocation: 2000, start: 2, end: 200});
        b[1] = IDAOData.Vesting({
            name: "Private", description: "private vesting", allocation: 3000, start: 3, end: 300
        });

        bytes memory encA = this._encodeVestingWrapper(a, 1);
        bytes memory encB = this._encodeVestingWrapper(b, 1);
        bytes memory encC = this._encodeVestingWrapper(c, 1);

        IDAOData.Vesting[] memory decA = this._decodeVestingWrapper(encA);
        IDAOData.Vesting[] memory decB = this._decodeVestingWrapper(encB);
        IDAOData.Vesting[] memory decC = this._decodeVestingWrapper(encC);

        // ensure that decoded data are equal to original
        assertTrue(keccak256(abi.encode(decA)) == keccak256(abi.encode(a)));
        assertTrue(keccak256(abi.encode(decB)) == keccak256(abi.encode(b)));
        assertTrue(keccak256(abi.encode(decC)) == keccak256(abi.encode(c)));
    }

    function testEncodeVesting_IncorrectVersion_Revert() public {
        IDAOData.Vesting[] memory a = new IDAOData.Vesting[](1);
        a[0] = IDAOData.Vesting({name: "Team", description: "team vesting", allocation: 1000, start: 1, end: 100});

        // encode with unsupported version should revert
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._encodeVestingWrapper(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion = abi.encode(INCORRECT_VERSION, a);
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._decodeVestingWrapper(payloadUnknownVersion);
    }

    function testEncodeDaoParameters() public view {
        IDAOData.DaoParameters memory a;
        a.vePeriod = 100;
        a.pvpFee = 10;
        a.minPower = 1000;
        a.ttBribe = 1;
        a.recoveryShare = 2;
        a.proposalThreshold = 50;

        bytes memory encA = this._encodeDaoParametersWrapper(a, 1);

        IDAOData.DaoParameters memory decA = this._decodeDaoParametersWrapper(encA);

        assertEq(decA.vePeriod, a.vePeriod);
        assertEq(decA.pvpFee, a.pvpFee);
        assertEq(decA.minPower, a.minPower);
        assertEq(decA.ttBribe, a.ttBribe);
        assertEq(decA.recoveryShare, a.recoveryShare);
        assertEq(decA.proposalThreshold, a.proposalThreshold);
    }

    function testEncodeDaoParameters_IncorrectVersion_Revert() public {
        IDAOData.DaoParameters memory a;
        a.vePeriod = 100;
        a.pvpFee = 10;
        a.minPower = 1000;
        a.ttBribe = 1;
        a.recoveryShare = 2;
        a.proposalThreshold = 50;

        // encode with unsupported version should revert
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._encodeDaoParametersWrapper(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion = abi.encode(
            INCORRECT_VERSION, a.vePeriod, a.pvpFee, a.minPower, a.ttBribe, a.recoveryShare, a.proposalThreshold
        );
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._decodeDaoParametersWrapper(payloadUnknownVersion);
    }

    function testEncodeDaoChainSettings() public view {
        IDAOData.DaoChainSettings memory a;
        a.bbRate = 101;

        bytes memory encA = this._encodeDaoChainSettingsWrapper(a, HostEncodingLib.PAYLOAD_API_VERSION);

        IDAOData.DaoChainSettings memory decA = this._decodeDaoChainSettingsWrapper(encA);

        assertEq(decA.bbRate, 101);
    }

    function testEncodeDaoChainSettings_IncorrectVersion_Revert() public {
        IDAOData.DaoChainSettings memory a;
        a.bbRate = 101;

        // encode with unsupported version should revert
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._encodeDaoChainSettingsWrapper(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion = abi.encode(INCORRECT_VERSION, a.bbRate);
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._decodeDaoChainSettingsWrapper(payloadUnknownVersion);
    }

    function testEncodeDaoNames() public view {
        IDAOData.DaoNames memory a = IDAOData.DaoNames({symbol: "NA", name: "NameA"});

        bytes memory encA = this._encodeDaoNamesWrapper(a, 1);

        IDAOData.DaoNames memory decA = this._decodeDaoNamesWrapper(encA);

        assertEq(decA.name, a.name);
        assertEq(decA.symbol, a.symbol);
    }

    function testEncodeDaoNames_IncorrectVersion_Revert() public {
        IDAOData.DaoNames memory a = IDAOData.DaoNames({symbol: "NA", name: "NameA"});

        // encode with unsupported version should revert
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._encodeDaoNamesWrapper(a, INCORRECT_VERSION);

        bytes memory encWrongVersionPayload = abi.encode(INCORRECT_VERSION, a.name, a.symbol);

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._decodeDaoNamesWrapper(encWrongVersionPayload);
    }

    function testEncodeSalt() public view {
        uint16[] memory contractIndices = new uint16[](2);
        contractIndices[0] = 1;
        contractIndices[1] = 2;

        bytes32[] memory salt = new bytes32[](2);
        salt[0] = "0x111";
        salt[1] = "0x222";

        bytes memory encA = this._encodeSalt(contractIndices, salt, HostEncodingLib.PAYLOAD_API_VERSION);

        (uint16[] memory retContractIndices, bytes32[] memory retSalt) = this._decodeSalt(encA);

        assertEq(retContractIndices.length, 2, "contractIndices length");
        assertEq(retSalt.length, 2, "salt length");
        assertEq(retContractIndices[0], contractIndices[0], "contractIndices[0]");
        assertEq(retContractIndices[1], contractIndices[1], "contractIndices[1]");
        assertEq(retSalt[0], salt[0], "salt[0]");
        assertEq(retSalt[1], salt[1], "salt[1]");
    }

    function testEncodeBridgedAction() public view {
        uint32[] memory dstEids = new uint32[](2);
        dstEids[0] = 3000;
        dstEids[1] = 5000;

        bytes[] memory payloads = new bytes[](2);
        {
            IDAOData.DaoParameters memory a;
            a.vePeriod = 100;
            a.pvpFee = 10;
            a.minPower = 1000;
            a.ttBribe = 1;
            a.recoveryShare = 2;
            a.proposalThreshold = 50;
            IDAOData.DaoNames memory b = IDAOData.DaoNames({symbol: "NA", name: "NameA"});

            payloads[0] = this._encodeDaoNamesWrapper(b, HostEncodingLib.PAYLOAD_API_VERSION); //some payload
            payloads[1] = this._encodeDaoParametersWrapper(a, HostEncodingLib.PAYLOAD_API_VERSION); // some other payload
        }

        bytes memory encA = this._encodeBridgedAction(
            uint16(IHost.BridgedActions.BRIDGE_DAO_1), dstEids, payloads, HostEncodingLib.PAYLOAD_API_VERSION
        );

        (uint16 actionKind, uint32[] memory eids, bytes[] memory actionPayloads) = this._decodeBridgedAction(encA);

        assertEq(eids.length, 2, "eids length");
        assertEq(actionPayloads.length, 2, "payloads length");
        assertEq(actionKind, uint16(IHost.BridgedActions.BRIDGE_DAO_1), "actionKind");
        assertEq(eids[0], dstEids[0], "eid0");
        assertEq(eids[1], dstEids[1], "eid1");
        assertEq(keccak256(actionPayloads[0]), keccak256(payloads[0]), "payload0");
        assertEq(keccak256(actionPayloads[1]), keccak256(payloads[1]), "payload1");
    }

    function testEncodeBridgeDaoParams() public view {
        IBridgedActions.BridgeDaoParams memory a;
        a.name = "abc";
        a.symbol = "symbol";
        a.chainSettings.bbRate = 101;

        a.daoParameters.vePeriod = 100;
        a.daoParameters.pvpFee = 10;
        a.daoParameters.minPower = 1000;
        a.daoParameters.ttBribe = 1;
        a.daoParameters.recoveryShare = 2;
        a.daoParameters.proposalThreshold = 50;

        a.saltContractIndices = new uint16[](2);
        a.saltContractIndices[0] = 1;
        a.saltContractIndices[1] = 2;

        a.salts = new bytes32[](2);
        a.salts[0] = "0x111";
        a.salts[1] = "0x222";

        bytes memory encA = this._encodeBridgeDaoParams(a, HostEncodingLib.PAYLOAD_API_VERSION);

        IBridgedActions.BridgeDaoParams memory b = this._decodeBridgeDaoParams(encA);

        assertEq(a.symbol, b.symbol, "symbol");
        assertEq(b.name, a.name, "name");
        assertEq(b.chainSettings.bbRate, a.chainSettings.bbRate, "bbRate");
        assertEq(b.daoParameters.vePeriod, a.daoParameters.vePeriod, "vePeriod");
        assertEq(b.daoParameters.pvpFee, a.daoParameters.pvpFee, "pvpFee");
        assertEq(b.daoParameters.minPower, a.daoParameters.minPower, "minPower");
        assertEq(b.daoParameters.ttBribe, a.daoParameters.ttBribe, "ttBribe");
        assertEq(b.daoParameters.recoveryShare, a.daoParameters.recoveryShare, "recoveryShare");
        assertEq(b.daoParameters.proposalThreshold, a.daoParameters.proposalThreshold, "proposalThreshold");
        assertEq(b.saltContractIndices.length, a.saltContractIndices.length, "saltContractIndices length");
        assertEq(b.salts.length, a.salts.length, "salts length");
        assertEq(b.saltContractIndices[0], a.saltContractIndices[0], "saltContractIndices[0]");
        assertEq(b.saltContractIndices[1], a.saltContractIndices[1], "saltContractIndices[1]");
        assertEq(b.salts[0], a.salts[0], "salts[0]");
        assertEq(b.salts[1], a.salts[1], "salts[1]");
    }

    function testEncodeBridgedUnits() public view {
        IBridgedActions.BridgedUnits memory data;
        data.unitIds = new string[](2);
        data.unitIds[0] = "unit1";
        data.unitIds[1] = "unit2";

        bytes memory encA = this._encodeBridgedUnits(data, HostEncodingLib.PAYLOAD_API_VERSION);

        IBridgedActions.BridgedUnits memory restored = this._decodeBridgedUnits(encA);

        assertEq(data.unitIds, restored.unitIds, "Same unit ids");
    }

    function testEncodeBridgedUnits_EmptyArray_Success() public view {
        IBridgedActions.BridgedUnits memory data;
        data.unitIds = new string[](0);

        bytes memory encA = this._encodeBridgedUnits(data, HostEncodingLib.PAYLOAD_API_VERSION);

        IBridgedActions.BridgedUnits memory restored = this._decodeBridgedUnits(encA);

        assertEq(data.unitIds, restored.unitIds, "Same unit ids");
    }

    function testEncodeUnitsMetaData() public view {
        (, ISegment4.UnitEmitData[] memory metaDataArray) = SampleDataLib.getUnitsSingle();
        ISegment4.UnitEmitData memory unitMetadata0 = metaDataArray[0];

        bytes memory encA = this._encodeUnitsMetaData(unitMetadata0);
        IDAOData.UnitEmitData memory restored = this._decodeUnitsMetaData(encA);

        assertEq(keccak256(abi.encode(restored)), keccak256(abi.encode(unitMetadata0)), "unitMetadata");
    }

    function testEncodeDaoDataInput() public view {
        IDAOData.DaoDataInput memory dao = HostUtilsLib.createTestDaoData();

        bytes memory encA = this._encodeDaoDataInput(dao);
        IDAOData.DaoDataInput memory restored = this._decodeDaoDataInput(encA);

        assertEq(keccak256(abi.encode(restored)), keccak256(abi.encode(dao)), "DaoDataInput");
    }

    function testEncodeProposal() public view {
        {
            IDAOData.Proposal memory data = IDAOData.Proposal({
                action: IDAOData.DAOAction.UPDATE_UNITS_3,
                validationRequired: true,
                votingRequired: true,
                validationStatus: IDAOData.ValidationStatus.APPROVED_1,
                id: "37097271",
                symbol: "aaaa",
                created: 15202617,
                status: IDAOData.VotingStatus.REJECTED_2,
                payloadHash: "0x61214220"
            });

            bytes memory encA = this._encodeProposal(data, HostEncodingLib.PAYLOAD_API_VERSION);
            IDAOData.Proposal memory restored = this._decodeProposal(encA);

            assertEq(keccak256(abi.encode(restored)), keccak256(abi.encode(data)), "proposal");
        }

        {
            IDAOData.Proposal memory data = IDAOData.Proposal({
                action: IDAOData.DAOAction.UPDATE_BRIDGED_DAO_9,
                validationRequired: false,
                votingRequired: true,
                validationStatus: IDAOData.ValidationStatus.REJECTED_2,
                id: "37097271",
                symbol: "aaaa adsfadf asdasdfasdf ",
                created: 0,
                status: IDAOData.VotingStatus.VOTING_0,
                payloadHash: ""
            });

            bytes memory encA = this._encodeProposal(data, HostEncodingLib.PAYLOAD_API_VERSION);
            IDAOData.Proposal memory restored = this._decodeProposal(encA);

            assertEq(keccak256(abi.encode(restored)), keccak256(abi.encode(data)), "proposal");
        }
    }

    function testEncodeProposal_IncorrectVersion_Revert() public {
        IDAOData.Proposal memory data = IDAOData.Proposal({
            action: IDAOData.DAOAction.UPDATE_UNITS_3,
            validationRequired: true,
            votingRequired: true,
            validationStatus: IDAOData.ValidationStatus.APPROVED_1,
            id: "37097271",
            symbol: "aaaa",
            created: 15202617,
            status: IDAOData.VotingStatus.REJECTED_2,
            payloadHash: "0x61214220"
        });

        // encode with unsupported version should revert
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._encodeProposal(data, INCORRECT_VERSION);

        bytes memory encA = abi.encode(data.symbol, data.created, data.status, data.payloadHash);
        encA = abi.encode(
            INCORRECT_VERSION,
            encA,
            data.action,
            data.validationRequired,
            data.votingRequired,
            data.validationStatus,
            data.id
        );

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._decodeProposal(encA);
    }

    function testEncodeDAOData() public {
        IDAOData.DaoData memory data = IDAOData.DaoData({
            symbol: "symbol",
            uid: 0x672027567634233,
            name: "DAO name",
            phase: IDAOData.LifecyclePhase.DEVELOPMENT_4,
            deployments: IDAOData.DaoDeploymentInfo({
                seedToken: makeAddr("seedToken"),
                tgeToken: makeAddr("tgeToken"),
                token: makeAddr("token"),
                xToken: makeAddr("xToken"),
                staking: makeAddr("staking"),
                daoToken: makeAddr("daoToken"),
                revenueRouter: makeAddr("revenueRouter"),
                recovery: makeAddr("recovery"),
                vesting: new address[](3),
                tokenBridge: makeAddr("tokenBridge"),
                xTokenBridge: makeAddr("xTokenBridge"),
                daoTokenBridge: makeAddr("daoTokenBridge")
            }),
            chainSettings: IDAOData.DaoChainSettings({bbRate: 100, multisig: address(0)}),
            unitIds: new string[](2),
            unitRevenue: new uint[](2),
            unitRevenueAssets: new address[](2),
            params: IDAOData.DaoParameters({
                vePeriod: type(uint32).max,
                pvpFee: type(uint16).max,
                minPower: 1000,
                ttBribe: type(uint16).max,
                recoveryShare: type(uint16).max,
                proposalThreshold: 50,
                totalSupply: 1e9
            }),
            initialChain: 1,
            socials: new string[](3),
            activity: new IDAOData.Activity[](4),
            images: SampleDataLib.getDaoImages(),
            units: new IDAOData.UnitData[](2),
            funding: new IDAOData.Funding[](2),
            vesting: new IDAOData.Vesting[](2),
            governanceSettings: IDAOData.GovernanceSettings({
                proposalThreshold: type(uint32).max, ttBribe: type(uint32).max
            }),
            deployer: makeAddr("deployer"),
            salts: new bytes32[](2),
            saltContractIndices: new uint16[](2),
            metaDataLocation: "daoMetaDataLocation",
            vestingContracts: new address[](2)
        });

        data.unitIds[0] = "unit1";
        data.unitIds[1] = "unit2";

        data.units[0] = IDAOData.UnitData({unitId: "unit1", chainIds: new uint[](4), developerUid: "developerUid0"});
        data.units[1] = IDAOData.UnitData({unitId: "unit1", chainIds: new uint[](1), developerUid: "developerUid0"});
        for (uint i; i < 4; i++) {
            data.units[0].chainIds[i] = i + 1;
        }
        data.units[1].chainIds[0] = 10;

        data.socials[0] = "twitter";
        data.socials[1] = "discord";
        data.socials[2] = "github";

        data.activity[0] = IDAOData.Activity.DEFI_PROTOCOL_OPERATOR_0;
        data.activity[1] = IDAOData.Activity.SAAS_OPERATOR_1;
        data.activity[2] = IDAOData.Activity.MEV_SEARCHER_2;
        data.activity[3] = IDAOData.Activity.BUILDER_3;

        data.funding[0] = IDAOData.Funding({
            fundingType: IDAOData.FundingType.SEED_0,
            start: 100,
            end: 200,
            minRaise: 1000,
            maxRaise: 5000,
            raised: 250,
            claim: 1
        });
        data.funding[1] = IDAOData.Funding({
            fundingType: IDAOData.FundingType.TGE_1,
            start: type(uint64).max,
            end: type(uint64).max,
            minRaise: type(uint).max,
            maxRaise: type(uint).max / 2,
            raised: 0,
            claim: type(uint64).max
        });

        data.unitRevenue[0] = 1e18;
        data.unitRevenue[1] = 2e18;
        data.unitRevenueAssets[0] = makeAddr("USDC");
        data.unitRevenueAssets[1] = makeAddr("USDT");
        data.salts[0] = "0x111";
        data.salts[1] = "0x222";
        data.saltContractIndices[0] = uint16(IDAOData.ContractIndices.SEED_TOKEN_1);
        data.saltContractIndices[1] = uint16(IDAOData.ContractIndices.TOKEN_3);

        data.vesting[0] =
            IDAOData.Vesting({name: "Team", description: "team vesting", allocation: 1000, start: 1, end: 100});
        data.vesting[1] =
            IDAOData.Vesting({name: "Seed", description: "seed vesting", allocation: 2000, start: 2, end: 200});

        data.vestingContracts[0] = makeAddr("vestingContract1");
        data.vestingContracts[1] = makeAddr("vestingContract2");

        bytes memory encA = this._encodeDAOData(data, HostEncodingLib.PAYLOAD_API_VERSION);
        IDAOData.DaoData memory restored = this._decodeDAOData(encA);

        assertEq(keccak256(abi.encode(restored)), keccak256(abi.encode(data)), "dao data");
    }

    //endregion -------------------------------------- Tests for encoding/decoding of structs

    //region -------------------------------------- Public wrappers of OsEncodingLib-functions for tests
    function _encodeDaoImagesWrapper(
        IDAOData.DaoImages memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoImages(data, version);
    }

    function _decodeDaoImagesWrapper(bytes memory payload) public pure returns (IDAOData.DaoImages memory data) {
        return HostEncodingLib.decodeDaoImages(payload);
    }

    function _encodeUnitsWrapper(
        IDAOData.UnitDataInput[] memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeUnits(data, version);
    }

    function _decodeUnitsWrapper(bytes memory payload) public pure returns (IDAOData.UnitDataInput[] memory data) {
        return HostEncodingLib.decodeUnits(payload);
    }

    function _encodeFundingWrapper(IDAOData.Funding memory data, uint16 version) public pure returns (bytes memory) {
        return HostEncodingLib.encodeFunding(data, version);
    }

    function _decodeFundingWrapper(bytes memory payload) public pure returns (IDAOData.Funding memory data) {
        return HostEncodingLib.decodeFunding(payload);
    }

    function _encodeVestingWrapper(
        IDAOData.Vesting[] memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeVesting(data, version);
    }

    function _decodeVestingWrapper(bytes memory payload) public pure returns (IDAOData.Vesting[] memory data) {
        return HostEncodingLib.decodeVesting(payload);
    }

    function _encodeDaoParametersWrapper(
        IDAOData.DaoParameters memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoParameters(data, version);
    }

    function _decodeDaoParametersWrapper(bytes memory payload)
        public
        pure
        returns (IDAOData.DaoParameters memory data)
    {
        return HostEncodingLib.decodeDaoParameters(payload);
    }

    function _encodeDaoChainSettingsWrapper(
        IDAOData.DaoChainSettings memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoChainSettings(data, version);
    }

    function _decodeDaoChainSettingsWrapper(bytes memory payload)
        public
        pure
        returns (IDAOData.DaoChainSettings memory data)
    {
        return HostEncodingLib.decodeDaoChainSettings(payload);
    }

    function _encodeDaoNamesWrapper(
        IDAOData.DaoNames memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoNames(data, version);
    }

    function _decodeDaoNamesWrapper(bytes memory payload) public pure returns (IDAOData.DaoNames memory data) {
        return HostEncodingLib.decodeDaoNames(payload);
    }

    function _encodeSalt(
        uint16[] memory contractIndices,
        bytes32[] memory salt,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeSalt(contractIndices, salt, version);
    }

    function _decodeSalt(bytes memory payload)
        public
        pure
        returns (uint16[] memory contractIndices, bytes32[] memory salt)
    {
        return HostEncodingLib.decodeSalt(payload);
    }

    function _encodeBridgedAction(
        uint16 actionKind,
        uint32[] memory dstEids,
        bytes[] memory actionPayloads,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeBridgedAction(actionKind, dstEids, actionPayloads, version);
    }

    function _decodeBridgedAction(bytes memory payload)
        public
        pure
        returns (uint16 actionKind, uint32[] memory dstEids, bytes[] memory actionPayloads)
    {
        return HostEncodingLib.decodeBridgedAction(payload);
    }

    function _encodeBridgeDaoParams(
        IBridgedActions.BridgeDaoParams memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeBridgeDaoParams(data, version);
    }

    function _decodeBridgeDaoParams(bytes memory payload)
        public
        pure
        returns (IBridgedActions.BridgeDaoParams memory data)
    {
        return HostEncodingLib.decodeBridgeDaoParams(payload);
    }

    function _encodeBridgedUnits(
        IBridgedActions.BridgedUnits memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeBridgedUnits(data, version);
    }

    function _decodeBridgedUnits(bytes memory payload) public pure returns (IBridgedActions.BridgedUnits memory data) {
        return HostEncodingLib.decodeBridgedUnits(payload);
    }

    function _encodeUnitsMetaData(IDAOData.UnitEmitData memory data) public pure returns (bytes memory dest) {
        dest = HostEncodingLib.encodeUnitsMetaData(data);
    }

    function _decodeUnitsMetaData(bytes memory payload) public pure returns (IDAOData.UnitEmitData memory data) {
        data = HostEncodingLib.decodeUnitsMetaData(payload);
    }

    function _encodeDaoDataInput(IDAOData.DaoDataInput memory dao) public pure returns (bytes memory dest) {
        dest = HostEncodingLib.encodeDaoDataInput(dao);
    }

    function _decodeDaoDataInput(bytes memory payload) public pure returns (IDAOData.DaoDataInput memory dao) {
        dao = HostEncodingLib.decodeDaoDataInput(payload);
    }

    function _encodeDAOData(IDAOData.DaoData memory data, uint16 version) public pure returns (bytes memory) {
        return HostEncodingLib.encodeDAOData(data, version);
    }

    function _decodeDAOData(bytes memory data) public pure returns (IDAOData.DaoData memory) {
        return HostEncodingLib.decodeDAOData(data);
    }

    function _encodeProposal(IDAOData.Proposal memory data, uint16 version) public pure returns (bytes memory) {
        return HostEncodingLib.encodeProposal(data, version);
    }

    function _decodeProposal(bytes memory data) public pure returns (IDAOData.Proposal memory) {
        return HostEncodingLib.decodeProposal(data);
    }

    //endregion -------------------------------------- Public wrappers of OsEncodingLib-functions for tests
}
