// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDAOMetadata} from "../../src/interfaces/IDAOMetadata.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {IBridgedActions} from "../../src/interfaces/IBridgedActions.sol";

library SampleDataLib {
    function getUnitPoolSample() internal pure returns (IDAOData.UnitPool memory) {
        return IDAOMetadata.UnitPool({
            repos: new string[](0),
            label: IDAOMetadata.GithubLabel({
                name: "protocolA", description: "Unit 0 Protocol A tasks", color: "0000FF"
            }),
            contractorSymbol: "PA"
        });
    }

    function getBridgeDaoParams() internal pure returns (IBridgedActions.BridgeDaoParams memory) {
        IBridgedActions.BridgeDaoParams memory p = IBridgedActions.BridgeDaoParams({
            symbol: "SYMBOL",
            name: "NAME",
            unitIds: new string[](2),
            chainSettings: ITokenomics.DaoChainSettings({bbRate: 10, multisig: address(0x123)}),
            daoParameters: ITokenomics.DaoParameters({
                vePeriod: 1, pvpFee: 2, minPower: 3, ttBribe: 4, recoveryShare: 5, proposalThreshold: 6, totalSupply: 7
            }),
            saltContractIndices: new uint16[](1),
            salts: new bytes32[](1)
        });

        p.unitIds[0] = "unit1";
        p.unitIds[1] = "unit2";

        p.salts[0] = bytes32("0xabc");
        p.saltContractIndices[0] = uint16(ITokenomics.ContractIndices.DAO_TOKEN_5);

        return p;
    }

    function getDaoChainSettings() internal pure returns (ITokenomics.DaoChainSettings memory) {
        return ITokenomics.DaoChainSettings({bbRate: 10, multisig: address(0x123)});
    }

    function getDaoParameters() internal pure returns (ITokenomics.DaoParameters memory) {
        return ITokenomics.DaoParameters({
            vePeriod: 1, pvpFee: 2, minPower: 3, ttBribe: 4, recoveryShare: 5, proposalThreshold: 6, totalSupply: 7
        });
    }

    function getSalts() internal pure returns (uint16[] memory contractIndices, bytes32[] memory salt) {
        contractIndices = new uint16[](3);
        salt = new bytes32[](3);

        contractIndices[0] = uint16(ITokenomics.ContractIndices.DAO_TOKEN_5);
        contractIndices[1] = uint16(ITokenomics.ContractIndices.DAO_TOKEN_BRIDGE_10);
        contractIndices[2] = uint16(ITokenomics.ContractIndices.STAKING_6);
        salt[0] = bytes32("0xabc1");
        salt[1] = bytes32("0xabc2");
        salt[2] = bytes32("0xabc3");
    }
}
