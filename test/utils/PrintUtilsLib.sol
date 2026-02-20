// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHost} from "../../src/interfaces/IHost.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";
import {console} from "forge-std/console.sol";

library PrintUtilsLib {
    function printUnits(IDAOData.UnitDataInput[] memory units) internal pure {
        for (uint i = 0; i < units.length; i++) {
            IDAOData.UnitDataInput memory unit = units[i];
            console.log(i, unit.unitId, unit.developerUid);
        }
    }

    function printUnits(IDAOData.UnitData[] memory units) internal pure {
        for (uint i = 0; i < units.length; i++) {
            IDAOData.UnitData memory unit = units[i];
            console.log(i, unit.unitId, unit.developerUid);
            printArray(unit.chainIds);
        }
    }

    function printArray(uint[] memory arr) internal pure {
        for (uint i = 0; i < arr.length; i++) {
            console.log(i, arr[i]);
        }
    }

    function printArray(string[] memory arr) internal pure {
        for (uint i = 0; i < arr.length; i++) {
            console.log(i, arr[i]);
        }
    }

    function printDaoData(IDAOData.DaoData memory data) internal pure {
        console.log("DAO Symbol:", data.symbol);
        console.log("DAO uid:", data.uid);
        console.log("DAO Name:", data.name);
        console.log("Deployer:", data.deployer);
        console.log("Phase:", uint8(data.phase));
        console.log("Initial chain", data.initialChain);

        console.log("Deployments:");
        console.log("  Seed Token:", data.deployments.seedToken);
        console.log("  TGE Token:", data.deployments.tgeToken);
        console.log("  Token:", data.deployments.token);
        console.log("  xToken:", data.deployments.xToken);
        console.log("  Staking:", data.deployments.staking);
        console.log("  DAO Token:", data.deployments.daoToken);
        console.log("  Revenue Router:", data.deployments.revenueRouter);
        console.log("  Recovery:", data.deployments.recovery);
        console.log("  Token Bridge:", data.deployments.tokenBridge);
        console.log("  xToken Bridge:", data.deployments.xTokenBridge);
        console.log("  DAO Token Bridge:", data.deployments.daoTokenBridge);
        for (uint i = 0; i < data.deployments.vesting.length; i++) {
            console.log(i, data.deployments.vesting[i]);
        }

        console.log("Chain settings:");
        console.log("  bbRate:", data.chainSettings.bbRate);

        console.log("DAO Params:");
        console.log("  vePeriod:", data.params.vePeriod);
        console.log("  pvpFee:", data.params.pvpFee);
        console.log("  minPower:", data.params.minPower);
        console.log("  ttBribe:", data.params.ttBribe);
        console.log("  recoveryShare:", data.params.recoveryShare);
        console.log("  proposalThreshold:", data.params.proposalThreshold);

        console.log("Socials:");
        for (uint i = 0; i < data.socials.length; i++) {
            console.log(" ", i, data.socials[i]);
        }

        console.log("Activity:");
        for (uint i = 0; i < data.activity.length; i++) {
            console.log(" ", i, uint(data.activity[i]));
        }

        console.log("Images:");
        console.log("  Seed Token:", data.images.seedToken);
        console.log("  TGE Token:", data.images.tgeToken);
        console.log("  Token:", data.images.token);
        console.log("  xToken:", data.images.xToken);
        console.log("  DAO Token:", data.images.daoToken);

        console.log("Units (unit.unitId, unitId):");
        for (uint i = 0; i < data.units.length; i++) {
            console.log(" ", i, data.units[i].unitId, data.unitIds[i]);
        }

        console.log("Funding: type, raised");
        for (uint i = 0; i < data.funding.length; i++) {
            console.log(" ", i, uint8(data.funding[i].fundingType), data.funding[i].raised);
            console.log("  start:", data.funding[i].start);
            console.log("  end:", data.funding[i].end);
            console.log("  claim:", data.funding[i].claim);
            console.log("  minRaise:", data.funding[i].minRaise);
            console.log("  maxRaise:", data.funding[i].maxRaise);
            console.log("  raised:", data.funding[i].raised);
        }

        console.log("daoMetaDataLocation", data.metaDataLocation);

        console.log("GovernanceSettings:");
        console.log("  proposalThreshold:", data.governanceSettings.proposalThreshold);
        console.log("  ttBribe:", data.governanceSettings.ttBribe);
    }

    function printTasks(IHost.Task[] memory tasks) internal pure {
        for (uint i; i < tasks.length; i++) {
            console.log(tasks[i].name);
        }
    }
}
