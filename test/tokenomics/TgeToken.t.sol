// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract TgeTokenTest is Test {
    function testStorageLocation() internal pure {
        console.log("keccak256(abi.encode(uint(keccak256(erc7201:stability.host-contracts.TgeToken))))");
        console.logBytes32(
            keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.TgeToken")) - 1))
                & ~bytes32(uint(0xff))
        );
    }
}
