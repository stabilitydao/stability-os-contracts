// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OsViewLib} from "../../../src/os/libs/OsViewLib.sol";

contract OsViewLibTest is Test {
    function testGetTokenName() public pure {
        string memory name = "abc";
        assertEq(OsViewLib.getTokenName(name, uint(OsViewLib.NamingTokenKind.SEED_0)), "abc SEED");
        assertEq(OsViewLib.getTokenName(name, uint(OsViewLib.NamingTokenKind.TGE_1)), "abc PRESALE");
        assertEq(OsViewLib.getTokenName(name, uint(OsViewLib.NamingTokenKind.TOKEN_2)), "abc");
        assertEq(OsViewLib.getTokenName(name, uint(OsViewLib.NamingTokenKind.XTOKEN_3)), "xabc");
        assertEq(OsViewLib.getTokenName(name, uint(OsViewLib.NamingTokenKind.DAO_4)), "abc DAO");
    }

    function testGetTokenSymbol() public pure {
        string memory name = "ABC";
        assertEq(OsViewLib.getTokenSymbol(name, uint(OsViewLib.NamingTokenKind.SEED_0)), "seedABC");
        assertEq(OsViewLib.getTokenSymbol(name, uint(OsViewLib.NamingTokenKind.TGE_1)), "saleABC");
        assertEq(OsViewLib.getTokenSymbol(name, uint(OsViewLib.NamingTokenKind.TOKEN_2)), "ABC");
        assertEq(OsViewLib.getTokenSymbol(name, uint(OsViewLib.NamingTokenKind.XTOKEN_3)), "xABC");
        assertEq(OsViewLib.getTokenSymbol(name, uint(OsViewLib.NamingTokenKind.DAO_4)), "ABC_DAO");
    }
}
