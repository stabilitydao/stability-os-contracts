// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SampleDataLib} from "./utils/SampleDataLib.sol";
import {Test} from "forge-std/Test.sol";
import {HostCodec} from "../src/HostCodec.sol";
import {IHost} from "../src/interfaces/IHost.sol";
import {ITokenomics} from "../src/interfaces/ITokenomics.sol";
import {IBridgedActions} from "../src/interfaces/IBridgedActions.sol";
import {IDAOMetadata} from "../src/interfaces/IDAOMetadata.sol";
import {IDAOData} from "../src/interfaces/IDAOData.sol";

contract HostCodecTest is Test {
    uint16 private constant INCORRECT_VERSION = type(uint16).max - 1;

    HostCodec public hostCodec;

    constructor() {
        hostCodec = new HostCodec();
    }

    function testEncodeDaoParameters() public view {
        ITokenomics.DaoParameters memory a;
        a.vePeriod = 100;
        a.pvpFee = 10;
        a.minPower = 1000;
        a.ttBribe = 1;
        a.recoveryShare = 2;
        a.proposalThreshold = 50;

        bytes memory encA = hostCodec.encode(a, 1);

        ITokenomics.DaoParameters memory decA = hostCodec.decodeDaoParameters(encA);

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
        hostCodec.encode(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion = abi.encode(
            INCORRECT_VERSION, a.vePeriod, a.pvpFee, a.minPower, a.ttBribe, a.recoveryShare, a.proposalThreshold
        );
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.decodeDaoParameters(payloadUnknownVersion);
    }

    function testEncodeDaoChainSettings() public view {
        ITokenomics.DaoChainSettings memory a;
        a.bbRate = 101;

        bytes memory encA = hostCodec.encode(a, hostCodec.PAYLOAD_API_VERSION());

        ITokenomics.DaoChainSettings memory decA = hostCodec.decodeDaoChainSettings(encA);

        assertEq(decA.bbRate, 101);
    }

    function testEncodeDaoChainSettingsBadPaths() public {
        ITokenomics.DaoChainSettings memory a;
        a.bbRate = 101;

        // encode with unsupported version should revert
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.encode(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion = abi.encode(INCORRECT_VERSION, a.bbRate);
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.decodeDaoChainSettings(payloadUnknownVersion);
    }

    function testEncodeSalt() public view {
        uint16[] memory contractIndices = new uint16[](2);
        contractIndices[0] = 1;
        contractIndices[1] = 2;

        bytes32[] memory salt = new bytes32[](2);
        salt[0] = "0x111";
        salt[1] = "0x222";

        bytes memory encA = hostCodec.encode(contractIndices, salt, hostCodec.PAYLOAD_API_VERSION());

        (uint16[] memory retContractIndices, bytes32[] memory retSalt) = hostCodec.decodeSalt(encA);

        assertEq(retContractIndices.length, 2, "contractIndices length");
        assertEq(retSalt.length, 2, "salt length");
        assertEq(retContractIndices[0], contractIndices[0], "contractIndices[0]");
        assertEq(retContractIndices[1], contractIndices[1], "contractIndices[1]");
        assertEq(retSalt[0], salt[0], "salt[0]");
        assertEq(retSalt[1], salt[1], "salt[1]");
    }

    function testEncodeSaltBadPaths() public {
        uint16[] memory contractIndices = new uint16[](2);
        contractIndices[0] = 1;
        contractIndices[1] = 2;

        bytes32[] memory salt = new bytes32[](2);
        salt[0] = "0x111";
        salt[1] = "0x222";

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.encode(contractIndices, salt, INCORRECT_VERSION);

        bytes memory encA = abi.encode(INCORRECT_VERSION, contractIndices, salt);

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.decodeSalt(encA);
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

        bytes memory encA = hostCodec.encode(a, hostCodec.PAYLOAD_API_VERSION());

        IBridgedActions.BridgeDaoParams memory b = hostCodec.decodeBridgeDaoParams(encA);

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

    function testEncodeFunding() public view {
        ITokenomics.Funding memory a;
        a.fundingType = ITokenomics.FundingType.SEED_0;
        a.start = 100;
        a.end = 200;
        a.minRaise = 1000;
        a.maxRaise = 5000;
        a.raised = 250;
        a.claim = 1;

        bytes memory encA = hostCodec.encode(a, 1);

        ITokenomics.Funding memory decA = hostCodec.decodeFunding(encA);

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
        hostCodec.encode(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion =
            abi.encode(INCORRECT_VERSION, a.fundingType, a.start, a.end, a.minRaise, a.maxRaise, a.raised, a.claim);

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.decodeFunding(payloadUnknownVersion);
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

        bytes memory encA = hostCodec.encode(a, 1);
        bytes memory encB = hostCodec.encode(b, 1);
        bytes memory encC = hostCodec.encode(c, 1);

        ITokenomics.Vesting[] memory decA = hostCodec.decodeVesting(encA);
        ITokenomics.Vesting[] memory decB = hostCodec.decodeVesting(encB);
        ITokenomics.Vesting[] memory decC = hostCodec.decodeVesting(encC);

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
        hostCodec.encode(a, INCORRECT_VERSION);

        // craft payload with unsupported version prefix and expect decode to revert
        bytes memory payloadUnknownVersion = abi.encode(INCORRECT_VERSION, a);
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.decodeVesting(payloadUnknownVersion);
    }

    function testEncodeDaoNames() public view {
        ITokenomics.DaoNames memory a = ITokenomics.DaoNames({symbol: "NA", name: "NameA"});

        bytes memory encA = hostCodec.encode(a, 1);

        ITokenomics.DaoNames memory decA = hostCodec.decodeDaoNames(encA);

        assertEq(decA.name, a.name);
        assertEq(decA.symbol, a.symbol);
    }

    function testEncodeDaoNamesBadPaths() public {
        ITokenomics.DaoNames memory a = ITokenomics.DaoNames({symbol: "NA", name: "NameA"});

        // encode with unsupported version should revert
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.encode(a, INCORRECT_VERSION);

        bytes memory encWrongVersionPayload = abi.encode(INCORRECT_VERSION, a.name, a.symbol);

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.decodeDaoNames(encWrongVersionPayload);
    }

    function testEncodeDaoImages() public view {
        ITokenomics.DaoImages memory a = ITokenomics.DaoImages({
            seedToken: "seedA", tgeToken: "tgeA", token: "tokenA", xToken: "xA", daoToken: "daoA"
        });

        bytes memory encA = hostCodec.encode(a, hostCodec.PAYLOAD_API_VERSION());

        ITokenomics.DaoImages memory decA = hostCodec.decodeImages(encA);

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
        hostCodec.encode(a, INCORRECT_VERSION);

        bytes memory payloadUnknownVersion =
            abi.encode(INCORRECT_VERSION, a.seedToken, a.tgeToken, a.token, a.xToken, a.daoToken);

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.decodeImages(payloadUnknownVersion);
    }

    function testEncodeSocials() public view {
        string[] memory socials = new string[](3);
        socials[0] = "twitterA";
        socials[1] = "discordA";
        socials[2] = "telegramA";

        bytes memory encA = hostCodec.encode(socials);

        string[] memory decA = hostCodec.decodeSocials(encA);

        assertEq(decA.length, 3);
        assertEq(decA[0], socials[0]);
        assertEq(decA[1], socials[1]);
        assertEq(decA[2], socials[2]);
    }

    function testEncodeUnits() public view {
        IDAOMetadata.UnitUiLink[] memory notEmptyUi = new IDAOMetadata.UnitUiLink[](2);
        notEmptyUi[0] = IDAOMetadata.UnitUiLink({title: "link1", href: "https://link1.com"});
        notEmptyUi[1] = IDAOMetadata.UnitUiLink({title: "link2", href: "https://link2.com"});

        string[] memory notEmptyApi = new string[](3);
        notEmptyApi[0] = "https://api1.com";
        notEmptyApi[1] = "https://api2.com";
        notEmptyApi[2] = "https://api3.com";

        IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](2);
        IDAOMetadata.UnitMetaData[] memory metas = new IDAOMetadata.UnitMetaData[](2);
        metas[0] = IDAOMetadata.UnitMetaData({
            name: "Unit A",
            status: IDAOMetadata.UnitStatus.LIVE_2,
            unitType: uint16(1),
            revenueShare: 1000,
            emoji: "emoji1",
            ui: notEmptyUi,
            api: notEmptyApi,
            pool: SampleDataLib.getUnitPoolSample()
        });
        units[0] = IDAOData.UnitDataInput({unitId: "unitA", developerUid: ""});
        metas[1] = IDAOMetadata.UnitMetaData({
            name: "Unit B1",
            status: IDAOMetadata.UnitStatus.BUILDING_1,
            unitType: uint16(2),
            revenueShare: 2000,
            emoji: "emoji2",
            ui: new IDAOMetadata.UnitUiLink[](0),
            api: new string[](0),
            pool: SampleDataLib.getUnitPoolSample()
        });
        units[1] = IDAOData.UnitDataInput({unitId: "unitB1", developerUid: "developerUid"});

        bytes memory encA = hostCodec.encode(units, hostCodec.PAYLOAD_API_VERSION());
        bytes memory encM = hostCodec.encode(metas, hostCodec.PAYLOAD_API_VERSION());

        IDAOData.UnitDataInput[] memory decA = hostCodec.decodeUnits(encA);
        IDAOData.UnitMetaData[] memory decM = hostCodec.decodeUnitsMetadata(encM);

        assertEq(keccak256(abi.encode(decA)), keccak256(abi.encode(units)), "units");
        assertEq(keccak256(abi.encode(decM)), keccak256(abi.encode(metas)), "metas");
    }

    function testEncodeUnitsBadPath() public {
        IDAOMetadata.UnitUiLink[] memory emptyUi;
        string[] memory emptyApi;

        IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](1);
        IDAOMetadata.UnitMetaData[] memory metas = new IDAOMetadata.UnitMetaData[](1);
        metas[0] = IDAOMetadata.UnitMetaData({
            name: "Unit A",
            status: IDAOMetadata.UnitStatus.LIVE_2,
            unitType: uint16(1),
            revenueShare: 1000,
            emoji: "emoji1",
            ui: emptyUi,
            api: emptyApi,
            pool: SampleDataLib.getUnitPoolSample()
        });
        units[0] = IDAOData.UnitDataInput({unitId: "unitA", developerUid: ""});

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.encode(metas, INCORRECT_VERSION);

        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.encode(units, INCORRECT_VERSION);

        bytes memory payloadUnknownVersion = abi.encode(INCORRECT_VERSION, units);
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.decodeUnits(payloadUnknownVersion);

        payloadUnknownVersion = abi.encode(INCORRECT_VERSION, metas);
        vm.expectRevert(IHost.UnsupportedStructVersion.selector);
        hostCodec.decodeUnitsMetadata(payloadUnknownVersion);
    }
}
