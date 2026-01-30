// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HostCodec} from "../src/HostCodec.sol";
import {IHost} from "../src/interfaces/IHost.sol";
import {ITokenomics} from "../src/interfaces/ITokenomics.sol";
import {IBridgedActions} from "../src/interfaces/IBridgedActions.sol";

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
}
