// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OsEncodingLib} from "../../../src/os/libs/OsEncodingLib.sol";
import {ITokenomics, IDAOUnit} from "../../../src/interfaces/ITokenomics.sol";
import {IOS} from "../../../src/interfaces/IOS.sol";

contract OsEncodingLibTest is Test {
    uint8 private constant INCORRECT_VERSION = 255;

    //region -------------------------------------- Public wrappers of OsEncodingLib-functions for tests
    function _encodeDaoImagesWrapper(
        ITokenomics.DaoImages memory data,
        uint8 version
    ) public pure returns (bytes memory) {
        return OsEncodingLib.encodeDaoImages(data, version);
    }

    function _decodeDaoImagesWrapper(bytes memory payload) public pure returns (ITokenomics.DaoImages memory data) {
        return OsEncodingLib.decodeDaoImages(payload);
    }

    function _encodeUnitsWrapper(IDAOUnit.UnitInfo[] memory data, uint8 version) public pure returns (bytes memory) {
        return OsEncodingLib.encodeUnits(data, version);
    }

    function _decodeUnitsWrapper(bytes memory payload) public pure returns (IDAOUnit.UnitInfo[] memory data) {
        return OsEncodingLib.decodeUnits(payload);
    }

    function _encodeFundingWrapper(ITokenomics.Funding memory data, uint8 version) public pure returns (bytes memory) {
        return OsEncodingLib.encodeFunding(data, version);
    }

    function _decodeFundingWrapper(bytes memory payload) public pure returns (ITokenomics.Funding memory data) {
        return OsEncodingLib.decodeFunding(payload);
    }

    function _encodeVestingWrapper(
        ITokenomics.Vesting[] memory data,
        uint8 version
    ) public pure returns (bytes memory) {
        return OsEncodingLib.encodeVesting(data, version);
    }

    function _decodeVestingWrapper(bytes memory payload) public pure returns (ITokenomics.Vesting[] memory data) {
        return OsEncodingLib.decodeVesting(payload);
    }

    function _encodeDaoParametersWrapper(
        ITokenomics.DaoParameters memory data,
        uint8 version
    ) public pure returns (bytes memory) {
        return OsEncodingLib.encodeDaoParameters(data, version);
    }

    function _decodeDaoParametersWrapper(bytes memory payload)
        public
        pure
        returns (ITokenomics.DaoParameters memory data)
    {
        return OsEncodingLib.decodeDaoParameters(payload);
    }

    function _encodeDaoNamesWrapper(
        ITokenomics.DaoNames memory data,
        uint8 version
    ) public pure returns (bytes memory) {
        return OsEncodingLib.encodeDaoNames(data, version);
    }

    function _decodeDaoNamesWrapper(bytes memory payload) public pure returns (ITokenomics.DaoNames memory data) {
        return OsEncodingLib.decodeDaoNames(payload);
    }
    //endregion -------------------------------------- Public wrappers of OsEncodingLib-functions for tests

    function testEncodeDaoImages() public pure {
        ITokenomics.DaoImages memory a = ITokenomics.DaoImages({
            seedToken: "seedA", tgeToken: "tgeA", token: "tokenA", xToken: "xA", daoToken: "daoA"
        });

        bytes memory encA = OsEncodingLib.encodeDaoImages(a, 1);

        ITokenomics.DaoImages memory decA = OsEncodingLib.decodeDaoImages(encA);

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

        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
        this._encodeDaoImagesWrapper(a, INCORRECT_VERSION);

        bytes memory payloadUnknownVersion =
            abi.encode(INCORRECT_VERSION, a.seedToken, a.tgeToken, a.token, a.xToken, a.daoToken);

        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
        this._decodeDaoImagesWrapper(payloadUnknownVersion);
    }

    function testEncodeUnits() public view {
        IDAOUnit.UnitInfo[] memory a = new IDAOUnit.UnitInfo[](1);
        IDAOUnit.UnitInfo[] memory b = new IDAOUnit.UnitInfo[](2);
        IDAOUnit.UnitInfo[] memory c = new IDAOUnit.UnitInfo[](0);

        IDAOUnit.UnitUiLink[] memory emptyUi = new IDAOUnit.UnitUiLink[](0);
        string[] memory emptyApi = new string[](0);

        IDAOUnit.UnitUiLink[] memory notEmptyUi = new IDAOUnit.UnitUiLink[](2);
        notEmptyUi[0] = IDAOUnit.UnitUiLink({label: "link1", url: "https://link1.com"});
        notEmptyUi[1] = IDAOUnit.UnitUiLink({label: "link2", url: "https://link2.com"});

        string[] memory notEmptyApi = new string[](3);
        notEmptyApi[0] = "https://api1.com";
        notEmptyApi[1] = "https://api2.com";
        notEmptyApi[2] = "https://api3.com";

        a[0] = IDAOUnit.UnitInfo({
            unitId: "unitA",
            name: "Unit A",
            status: IDAOUnit.UnitStatus.LIVE_2,
            unitType: uint16(1),
            revenueShare: 1000,
            emoji: "emoji1",
            ui: emptyUi,
            api: emptyApi
        });

        b[0] = IDAOUnit.UnitInfo({
            unitId: "unitB1",
            name: "Unit B1",
            status: IDAOUnit.UnitStatus.BUILDING_1,
            unitType: uint16(2),
            revenueShare: 2000,
            emoji: "emoji2",
            ui: notEmptyUi,
            api: emptyApi
        });
        b[1] = IDAOUnit.UnitInfo({
            unitId: "unitB2",
            name: "Unit B2",
            status: IDAOUnit.UnitStatus.RESEARCH_0,
            unitType: uint16(3),
            revenueShare: 3000,
            emoji: "emoji3",
            ui: notEmptyUi,
            api: notEmptyApi
        });

        // encode with supported version
        bytes memory encA = this._encodeUnitsWrapper(a, 1);
        bytes memory encB = this._encodeUnitsWrapper(b, 1);
        bytes memory encC = this._encodeUnitsWrapper(c, 1);

        IDAOUnit.UnitInfo[] memory decA = this._decodeUnitsWrapper(encA);
        IDAOUnit.UnitInfo[] memory decB = this._decodeUnitsWrapper(encB);
        IDAOUnit.UnitInfo[] memory decC = this._decodeUnitsWrapper(encC);

        assertTrue(keccak256(abi.encode(decA)) == keccak256(abi.encode(a)));
        assertTrue(keccak256(abi.encode(decB)) == keccak256(abi.encode(b)));
        assertTrue(keccak256(abi.encode(decC)) == keccak256(abi.encode(c)));
    }

    function testEncodeUnitsBadPaths() public {
        IDAOUnit.UnitInfo[] memory a = new IDAOUnit.UnitInfo[](1);

        a[0] = IDAOUnit.UnitInfo({
            unitId: "unitA",
            name: "Unit A",
            status: IDAOUnit.UnitStatus(uint8(0)),
            unitType: uint16(1),
            revenueShare: 1000,
            emoji: "emoji",
            ui: new IDAOUnit.UnitUiLink[](0),
            api: new string[](0)
        });

        // encode with incorrect version should revert
        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
        this._encodeUnitsWrapper(a, INCORRECT_VERSION);

        // craft payload with unsupported version and expect decode to revert
        bytes memory payloadUnknownVersion = abi.encode(INCORRECT_VERSION, a);

        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
        this._decodeUnitsWrapper(payloadUnknownVersion);
    }

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
        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
        this._encodeFundingWrapper(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion =
            abi.encode(INCORRECT_VERSION, a.fundingType, a.start, a.end, a.minRaise, a.maxRaise, a.raised, a.claim);

        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
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
        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
        this._encodeVestingWrapper(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion = abi.encode(INCORRECT_VERSION, a);
        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
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
        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
        this._encodeDaoParametersWrapper(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion = abi.encode(
            INCORRECT_VERSION, a.vePeriod, a.pvpFee, a.minPower, a.ttBribe, a.recoveryShare, a.proposalThreshold
        );
        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
        this._decodeDaoParametersWrapper(payloadUnknownVersion);
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
        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
        this._encodeDaoNamesWrapper(a, INCORRECT_VERSION);

        bytes memory encWrongVersionPayload = abi.encode(INCORRECT_VERSION, a.name, a.symbol);

        vm.expectRevert(IOS.UnsupportedStructVersion.selector);
        this._decodeDaoNamesWrapper(encWrongVersionPayload);
    }
}
