// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDAOMetadata} from "../../src/interfaces/IDAOMetadata.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";

library SampleDataLib {
    function _getUnitPoolSample() internal pure returns (IDAOData.UnitPool memory) {
        return IDAOMetadata.UnitPool({
            repos: new string[](0),
            label: IDAOMetadata.GithubLabel({
                name: "protocolA",
                description: "Unit 0 Protocol A tasks",
                color: "0000FF"
            }),
            contractorSymbol: "PA"
        });
    }
}
