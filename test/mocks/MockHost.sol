// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

contract MockHost {
    address public dataReader;

    function setDataReader(address dataReader_) external {
        dataReader = dataReader_;
    }
}
