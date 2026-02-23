// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Test.sol";

library CommonUtilsLib {
    function skip(Vm vm, uint256 time) internal {
        vm.warp(vm.getBlockTimestamp() + time);
    }
}