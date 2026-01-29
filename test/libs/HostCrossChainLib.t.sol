// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HostCrossChainLib} from "../../src/libs/HostCrossChainLib.sol";
import {IHost} from "../../src/interfaces/IHost.sol";

contract HostCrossChainLibCaller {
    function packNewDaoSymbol(string memory daoSymbol) external pure returns (bytes memory) {
        return HostCrossChainLib.packMessageNewDaoSymbol(daoSymbol);
    }

    function unpackNewDaoSymbol(bytes memory message) external pure returns (string memory) {
        return HostCrossChainLib.unpackMessageNewDaoSymbol(message);
    }

    function packRenameSymbol(string memory oldSymbol, string memory newSymbol) external pure returns (bytes memory) {
        return HostCrossChainLib.packMessageRenameSymbol(oldSymbol, newSymbol);
    }

    function unpackRenameSymbol(bytes memory message) external pure returns (string memory, string memory) {
        return HostCrossChainLib.unpackMessageRenameSymbol(message);
    }

    function packBridgedActionHash(uint16 actionKind, uint daoUid, bytes32 actionHash) external pure returns (bytes memory) {
        return HostCrossChainLib.packMessageBridgedActionHash(actionKind, daoUid, actionHash);
    }

    function unpackBridgedActionHash(bytes memory message) external pure returns (uint16, uint, bytes32) {
        return HostCrossChainLib.unpackMessageBridgedActionHash(message);
    }
}

contract HostCrossChainLibTest is Test {
    HostCrossChainLibCaller caller;

    function setUp() public {
        caller = new HostCrossChainLibCaller();
    }

    function testPackUnpackNewDaoSymbol() public view {
        string memory sym = "MY_DAO";
        bytes memory msgData = caller.packNewDaoSymbol(sym);

        string memory decoded = caller.unpackNewDaoSymbol(msgData);
        assertEq(decoded, sym);

        (uint16 tag,) = abi.decode(msgData, (uint16, string));
        assertEq(uint256(tag), uint256(uint16(IHost.CrossChainMessages.NEW_DAO_SYMBOL_0)));
    }

    function testPackUnpackRenameSymbol() public view {
        string memory oldSym = "OLD";
        string memory newSym = "NEW_NEW";
        bytes memory msgData = caller.packRenameSymbol(oldSym, newSym);

        (string memory dOld, string memory dNew) = caller.unpackRenameSymbol(msgData);
        assertEq(dOld, oldSym);
        assertEq(dNew, newSym);

        (uint16 tag, ,) = abi.decode(msgData, (uint16, string, string));
        assertEq(uint256(tag), uint256(uint16(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1)));
    }

    function testPackUnpackBridgedActionHash() public view {
        uint16 actionKind = 7;
        uint daoUid = 12345;
        bytes32 actionHash = keccak256(abi.encodePacked("action"));

        bytes memory msgData = caller.packBridgedActionHash(actionKind, daoUid, actionHash);

        (uint16 dKind, uint dUid, bytes32 dHash) = caller.unpackBridgedActionHash(msgData);
        assertEq(uint256(dKind), uint256(actionKind));
        assertEq(dUid, daoUid);
        assertEq(dHash, actionHash);

        (uint16 tag,) = abi.decode(msgData, (uint16, uint16));
        assertEq(uint256(tag), uint256(uint16(IHost.CrossChainMessages.DAO_BRIDGED_ACTION_HASH_2)));
    }
}
