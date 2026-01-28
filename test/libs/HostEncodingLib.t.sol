// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HostEncodingLib} from "../../src/libs/HostEncodingLib.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IBridgedActions} from "../../src/interfaces/IBridgedActions.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";

contract HostEncodingLibTest is Test {
    uint8 private constant INCORRECT_VERSION = 255;

    //region -------------------------------------- Public wrappers of OsEncodingLib-functions for tests
    function _encodeDaoImagesWrapper(
        ITokenomics.DaoImages memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoImages(data, version);
    }

    function _decodeDaoImagesWrapper(bytes memory payload) public pure returns (ITokenomics.DaoImages memory data) {
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

    function _encodeFundingWrapper(ITokenomics.Funding memory data, uint16 version) public pure returns (bytes memory) {
        return HostEncodingLib.encodeFunding(data, version);
    }

    function _decodeFundingWrapper(bytes memory payload) public pure returns (ITokenomics.Funding memory data) {
        return HostEncodingLib.decodeFunding(payload);
    }

    function _encodeVestingWrapper(
        ITokenomics.Vesting[] memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeVesting(data, version);
    }

    function _decodeVestingWrapper(bytes memory payload) public pure returns (ITokenomics.Vesting[] memory data) {
        return HostEncodingLib.decodeVesting(payload);
    }

    function _encodeDaoParametersWrapper(
        ITokenomics.DaoParameters memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoParameters(data, version);
    }

    function _decodeDaoParametersWrapper(bytes memory payload)
        public
        pure
        returns (ITokenomics.DaoParameters memory data)
    {
        return HostEncodingLib.decodeDaoParameters(payload);
    }

    function _encodeDaoChainSettingsWrapper(
        ITokenomics.DaoChainSettings memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoChainSettings(data, version);
    }

    function _decodeDaoChainSettingsWrapper(bytes memory payload)
    public
    pure
    returns (ITokenomics.DaoChainSettings memory data)
    {
        return HostEncodingLib.decodeDaoChainSettings(payload);
    }

    function _encodeDaoNamesWrapper(
        ITokenomics.DaoNames memory data,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeDaoNames(data, version);
    }

    function _decodeDaoNamesWrapper(bytes memory payload) public pure returns (ITokenomics.DaoNames memory data) {
        return HostEncodingLib.decodeDaoNames(payload);
    }

    function _encodeSalt(
        uint16[] memory contractIndices,
        bytes32[] memory salt,
        uint16 version
    ) public pure returns (bytes memory) {
        return HostEncodingLib.encodeSalt(contractIndices, salt, version);
    }

    function _decodeSalt(bytes memory payload) public pure returns (uint16[] memory contractIndices, bytes32[] memory salt) {
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

    function _decodeBridgedAction(bytes memory payload) public pure returns (uint16 actionKind, uint32[] memory dstEids, bytes[] memory actionPayloads) {
        return HostEncodingLib.decodeBridgedAction(payload);
    }

    function _encodeBridgeDaoParams(IBridgedActions.BridgeDaoParams memory data, uint16 version) public pure returns (bytes memory) {
        return HostEncodingLib.encodeBridgeDaoParams(data, version);
    }

    function _decodeBridgeDaoParams(bytes memory payload) public pure returns (IBridgedActions.BridgeDaoParams memory data) {
        return HostEncodingLib.decodeBridgeDaoParams(payload);
    }
    //endregion -------------------------------------- Public wrappers of OsEncodingLib-functions for tests

    function testEncodeDaoImages() public pure {
        ITokenomics.DaoImages memory a = ITokenomics.DaoImages({
            seedToken: "seedA", tgeToken: "tgeA", token: "tokenA", xToken: "xA", daoToken: "daoA"
        });

        bytes memory encA = HostEncodingLib.encodeDaoImages(a, 1);

        ITokenomics.DaoImages memory decA = HostEncodingLib.decodeDaoImages(encA);

        assertEq(decA.seedToken, a.seedToken);
        assertEq(decA.tgeToken, a.tgeToken);
        assertEq(decA.token, a.token);
        assertEq(decA.xToken, a.xToken);
        assertEq(decA.daoToken, a.daoToken);
    }

    function testEncodeDaoImagesBadPaths() public {
        ITokenomics.DaoImages memory a = ITokenomics.DaoImages({
            seedToken: "seedA", tgeToken: "tgeA", token: "tokenA", xToken: "xA", daoToken: "daoA"
        });

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._encodeDaoImagesWrapper(a, INCORRECT_VERSION);

        bytes memory payloadUnknownVersion =
            abi.encode(INCORRECT_VERSION, a.seedToken, a.tgeToken, a.token, a.xToken, a.daoToken);

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._decodeDaoImagesWrapper(payloadUnknownVersion);
    }

    // todo
    //    function testEncodeUnits() public view {
    //        IDAOUnit.UnitInfo[] memory a = new IDAOUnit.UnitInfo[](1);
    //        IDAOUnit.UnitInfo[] memory b = new IDAOUnit.UnitInfo[](2);
    //        IDAOUnit.UnitInfo[] memory c = new IDAOUnit.UnitInfo[](0);
    //
    //        IDAOUnit.UnitUiLink[] memory emptyUi = new IDAOUnit.UnitUiLink[](0);
    //        string[] memory emptyApi = new string[](0);
    //
    //        IDAOUnit.UnitUiLink[] memory notEmptyUi = new IDAOUnit.UnitUiLink[](2);
    //        notEmptyUi[0] = IDAOUnit.UnitUiLink({title: "link1", href: "https://link1.com"});
    //        notEmptyUi[1] = IDAOUnit.UnitUiLink({title: "link2", href: "https://link2.com"});
    //
    //        string[] memory notEmptyApi = new string[](3);
    //        notEmptyApi[0] = "https://api1.com";
    //        notEmptyApi[1] = "https://api2.com";
    //        notEmptyApi[2] = "https://api3.com";
    //
    //        a[0].metaData = IDAOUnit.UnitMetaData({
    //            name: "Unit A",
    //            status: IDAOUnit.UnitStatus.LIVE_2,
    //            unitType: uint16(1),
    //            revenueShare: 1000,
    //            emoji: "emoji1",
    //            ui: emptyUi,
    //            api: emptyApi
    //        });
    //        a[0].chainData = IDAOUnit.UnitChainData({
    //            unitId: "unitA",
    //            developerUid: ""
    //        });
    //
    //        b[0].metaData = IDAOUnit.UnitMetaData({
    //            name: "Unit B1",
    //            status: IDAOUnit.UnitStatus.BUILDING_1,
    //            unitType: uint16(2),
    //            revenueShare: 2000,
    //            emoji: "emoji2",
    //            ui: notEmptyUi,
    //            api: emptyApi
    //        });
    //        b[0].chainData = IDAOUnit.UnitChainData({
    //            unitId: "unitB1",
    //            developerUid: ""
    //        });
    //        b[1].metaData = IDAOUnit.UnitMetaData({
    //            name: "Unit B2",
    //            status: IDAOUnit.UnitStatus.RESEARCH_0,
    //            unitType: uint16(3),
    //            revenueShare: 3000,
    //            emoji: "emoji3",
    //            ui: notEmptyUi,
    //            api: notEmptyApi
    //        });
    //        b[1].chainData = IDAOUnit.UnitChainData({
    //            unitId: "unitB2",
    //            developerUid: ""
    //        });
    //
    //        // encode with supported version
    //        bytes memory encA = this._encodeUnitsWrapper(a, 1);
    //        bytes memory encB = this._encodeUnitsWrapper(b, 1);
    //        bytes memory encC = this._encodeUnitsWrapper(c, 1);
    //
    //        IDAOUnit.UnitInfo[] memory decA = this._decodeUnitsWrapper(encA);
    //        IDAOUnit.UnitInfo[] memory decB = this._decodeUnitsWrapper(encB);
    //        IDAOUnit.UnitInfo[] memory decC = this._decodeUnitsWrapper(encC);
    //
    //        assertTrue(keccak256(abi.encode(decA)) == keccak256(abi.encode(a)));
    //        assertTrue(keccak256(abi.encode(decB)) == keccak256(abi.encode(b)));
    //        assertTrue(keccak256(abi.encode(decC)) == keccak256(abi.encode(c)));
    //    }
    //
    //    function testEncodeUnitsBadPaths() public {
    //        IDAOUnit.UnitInfo[] memory a = new IDAOUnit.UnitInfo[](1);
    //
    //        a[0].metaData = IDAOUnit.UnitMetaData({
    //            name: "Unit A",
    //            status: IDAOUnit.UnitStatus(uint8(0)),
    //            unitType: uint16(1),
    //            revenueShare: 1000,
    //            emoji: "emoji",
    //            ui: new IDAOUnit.UnitUiLink[](0),
    //            api: new string[](0)
    //        });
    //        a[0].chainData = IDAOUnit.UnitChainData({
    //            unitId: "unitA",
    //            developerUid: ""
    //        });
    //        // encode with incorrect version should revert
    //        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
    //        this._encodeUnitsWrapper(a, INCORRECT_VERSION);
    //
    //        // craft payload with unsupported version and expect decode to revert
    //        bytes memory payloadUnknownVersion = abi.encode(INCORRECT_VERSION, a);
    //
    //        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
    //        this._decodeUnitsWrapper(payloadUnknownVersion);
    //    }

    function testEncodeFunding() public view {
        ITokenomics.Funding memory a;
        a.fundingType = ITokenomics.FundingType.SEED_0;
        a.start = 100;
        a.end = 200;
        a.minRaise = 1000;
        a.maxRaise = 5000;
        a.raised = 250;
        a.claim = 1;

        bytes memory encA = this._encodeFundingWrapper(a, 1);

        ITokenomics.Funding memory decA = this._decodeFundingWrapper(encA);

        assertEq(uint8(decA.fundingType), uint8(a.fundingType));
        assertEq(uint64(decA.start), uint64(a.start));
        assertEq(uint64(decA.end), uint64(a.end));
        assertEq(decA.minRaise, a.minRaise);
        assertEq(decA.maxRaise, a.maxRaise);
        assertEq(decA.raised, a.raised);
        assertEq(decA.claim, a.claim);
    }

    function testEncodeFundingBadPaths() public {
        ITokenomics.Funding memory a;
        a.fundingType = ITokenomics.FundingType(uint8(0));
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
        ITokenomics.Vesting[] memory a = new ITokenomics.Vesting[](1);
        ITokenomics.Vesting[] memory b = new ITokenomics.Vesting[](2);
        ITokenomics.Vesting[] memory c = new ITokenomics.Vesting[](0);

        a[0] = ITokenomics.Vesting({name: "Team", description: "team vesting", allocation: 1000, start: 1, end: 100});
        b[0] = ITokenomics.Vesting({name: "Seed", description: "seed vesting", allocation: 2000, start: 2, end: 200});
        b[1] = ITokenomics.Vesting({
            name: "Private", description: "private vesting", allocation: 3000, start: 3, end: 300
        });

        bytes memory encA = this._encodeVestingWrapper(a, 1);
        bytes memory encB = this._encodeVestingWrapper(b, 1);
        bytes memory encC = this._encodeVestingWrapper(c, 1);

        ITokenomics.Vesting[] memory decA = this._decodeVestingWrapper(encA);
        ITokenomics.Vesting[] memory decB = this._decodeVestingWrapper(encB);
        ITokenomics.Vesting[] memory decC = this._decodeVestingWrapper(encC);

        // ensure that decoded data are equal to original
        assertTrue(keccak256(abi.encode(decA)) == keccak256(abi.encode(a)));
        assertTrue(keccak256(abi.encode(decB)) == keccak256(abi.encode(b)));
        assertTrue(keccak256(abi.encode(decC)) == keccak256(abi.encode(c)));
    }

    function testEncodeVestingBadPaths() public {
        ITokenomics.Vesting[] memory a = new ITokenomics.Vesting[](1);
        a[0] = ITokenomics.Vesting({name: "Team", description: "team vesting", allocation: 1000, start: 1, end: 100});

        // encode with unsupported version should revert
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._encodeVestingWrapper(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion = abi.encode(INCORRECT_VERSION, a);
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        this._decodeVestingWrapper(payloadUnknownVersion);
    }

    function testEncodeDaoParameters() public view {
        ITokenomics.DaoParameters memory a;
        a.vePeriod = 100;
        a.pvpFee = 10;
        a.minPower = 1000;
        a.ttBribe = 1;
        a.recoveryShare = 2;
        a.proposalThreshold = 50;

        bytes memory encA = this._encodeDaoParametersWrapper(a, 1);

        ITokenomics.DaoParameters memory decA = this._decodeDaoParametersWrapper(encA);

        assertEq(decA.vePeriod, a.vePeriod);
        assertEq(decA.pvpFee, a.pvpFee);
        assertEq(decA.minPower, a.minPower);
        assertEq(decA.ttBribe, a.ttBribe);
        assertEq(decA.recoveryShare, a.recoveryShare);
        assertEq(decA.proposalThreshold, a.proposalThreshold);
    }

    function testEncodeDaoParametersBadPaths() public {
        ITokenomics.DaoParameters memory a;
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
        ITokenomics.DaoChainSettings memory a;
        a.bbRate = 101;

        bytes memory encA = this._encodeDaoChainSettingsWrapper(a, HostEncodingLib.PAYLOAD_API_VERSION);

        ITokenomics.DaoChainSettings memory decA = this._decodeDaoChainSettingsWrapper(encA);

        assertEq(decA.bbRate, 101);
    }

    function testEncodeDaoChainSettingsBadPaths() public {
        ITokenomics.DaoChainSettings memory a;
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
        ITokenomics.DaoNames memory a = ITokenomics.DaoNames({symbol: "NA", name: "NameA"});

        bytes memory encA = this._encodeDaoNamesWrapper(a, 1);

        ITokenomics.DaoNames memory decA = this._decodeDaoNamesWrapper(encA);

        assertEq(decA.name, a.name);
        assertEq(decA.symbol, a.symbol);
    }

    function testEncodeDaoNamesBadPaths() public {
        ITokenomics.DaoNames memory a = ITokenomics.DaoNames({symbol: "NA", name: "NameA"});

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
            ITokenomics.DaoParameters memory a;
            a.vePeriod = 100;
            a.pvpFee = 10;
            a.minPower = 1000;
            a.ttBribe = 1;
            a.recoveryShare = 2;
            a.proposalThreshold = 50;
            ITokenomics.DaoNames memory b = ITokenomics.DaoNames({symbol: "NA", name: "NameA"});

            payloads[0] = this._encodeDaoNamesWrapper(b, HostEncodingLib.PAYLOAD_API_VERSION); //some payload
            payloads[1] = this._encodeDaoParametersWrapper(a, HostEncodingLib.PAYLOAD_API_VERSION); // some other payload
        }

        bytes memory encA = this._encodeBridgedAction(uint16(IHost.BridgedActions.BRIDGE_DAO_1), dstEids, payloads, HostEncodingLib.PAYLOAD_API_VERSION);

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
}
