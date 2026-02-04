// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

contract MockDataReader {
    mapping(uint daoUid => mapping(uint namingTokenKind => string name)) internal _names;
    mapping(uint daoUid => mapping(uint namingTokenKind => string symbol)) internal _symbols;

    function setName(uint daoUid, uint namingTokenKind, string memory name_) external {
        _names[daoUid][namingTokenKind] = name_;
    }

    function setSymbol(uint daoUid, uint namingTokenKind, string memory symbol_) external {
        _symbols[daoUid][namingTokenKind] = symbol_;
    }

    function getTokenName(uint daoUid, uint namingTokenKind) external view returns (string memory) {
        return _names[daoUid][namingTokenKind];
    }

    function getTokenSymbol(uint daoUid, uint namingTokenKind) external view returns (string memory) {
        return _symbols[daoUid][namingTokenKind];
    }
}
