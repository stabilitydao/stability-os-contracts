// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HostViewLib} from "../../src/libs/HostViewLib.sol";

contract HostViewLibTest is Test {
    function testGetTokenName() public pure {
        string memory name = "abc";
        assertEq(HostViewLib.getTokenName(name, uint(HostViewLib.NamingTokenKind.SEED_0)), "abc SEED");
        assertEq(HostViewLib.getTokenName(name, uint(HostViewLib.NamingTokenKind.TGE_1)), "abc PRESALE");
        assertEq(HostViewLib.getTokenName(name, uint(HostViewLib.NamingTokenKind.TOKEN_2)), "abc");
        assertEq(HostViewLib.getTokenName(name, uint(HostViewLib.NamingTokenKind.XTOKEN_3)), "xabc");
        assertEq(HostViewLib.getTokenName(name, uint(HostViewLib.NamingTokenKind.DAO_4)), "abc DAO");
    }

    function testGetTokenSymbol() public pure {
        string memory name = "ABC";
        assertEq(HostViewLib.getTokenSymbol(name, uint(HostViewLib.NamingTokenKind.SEED_0)), "seedABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(HostViewLib.NamingTokenKind.TGE_1)), "saleABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(HostViewLib.NamingTokenKind.TOKEN_2)), "ABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(HostViewLib.NamingTokenKind.XTOKEN_3)), "xABC");
        assertEq(HostViewLib.getTokenSymbol(name, uint(HostViewLib.NamingTokenKind.DAO_4)), "ABC_DAO");
    }
}
