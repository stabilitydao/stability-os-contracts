// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {HostLib} from "./HostLib.sol";
import {HostUpdateLib} from "./HostUpdateLib.sol";
import {HostActionsLib} from "./HostActionsLib.sol";
import {HostEncodingLib} from "./HostEncodingLib.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";

/// @dev All actions available for admin only (i.e. Add live DAO)
/// @dev The library is extracted from HostActionsLib to reduce its size
library HostRestrictedActionsLib {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @dev Add exist DAO to Host
    function updateByAdmin(IHost.AdminUpdateActions actionIndex, bytes memory payload) external {
        if (actionIndex == IHost.AdminUpdateActions.ADD_LIVE_DAO_0) {
            IDAOData.DaoDataInput memory dao = HostEncodingLib.decodeDaoDataInput(payload);
            _addLiveDAO(dao);
        } else {
            revert IHost.UnknownRestrictedAction();
        }
    }

    /// @notice Add live DAO verified off-chain into the system
    function _addLiveDAO(IDAOData.DaoDataInput memory dao) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        (uint daoUid,) = HostLib.generateDaoUid($);

        // ------------------------- Segment 2

        HostLib.DaoDataSegment2 memory daoData2;
        daoData2.name = dao.name;
        daoData2.symbol = dao.symbol;
        daoData2.phase = dao.phase;
        daoData2.unitIds = new string[](dao.units.length);

        HostUpdateLib.validate(daoUid, dao.phase, daoData2, dao.params, dao.funding, dao.activity);

        // ------------------------- Prepare units data
        require(dao.units.length == dao.unitDataToEmit.length, IHost.IncorrectArrayLengths());

        for (uint i; i < dao.units.length; i++) {
            bytes32 hashUnitId = HostLib.getUnitKey(daoUid, dao.units[i].unitId);
            HostLib.UnitLocal storage unit = $.units[hashUnitId];

            daoData2.unitIds[i] = dao.units[i].unitId;
            require(unit.daoUid == 0, IHost.UnitAlreadyRegistered());

            unit.daoUid = daoUid;
            unit.unitId = dao.units[i].unitId;
            unit.developerUid = dao.units[i].developerUid;
            unit.chainIds.add(block.chainid);

            emit IHost.DaoUnitUpdatedInstantly(daoUid, dao.units[i].unitId, dao.unitDataToEmit[i]);
        }

        $.segment2[daoUid] = daoData2;

        // ------------------------- Segment 3
        HostLib.DaoDataSegment3 storage segment3 = $.segment3[daoUid];
        segment3.initialChain = block.chainid; // TODO: how to add exist bridged DAO?
        segment3.deployer = dao.deployer;
        segment3.activity = dao.activity;
        { // segment3.socials = dao.socials;
            uint len = dao.socials.length;
            for (uint i; i < len; i++) {
                segment3.socials.push(dao.socials[i]);
            }
        }

        // todo validate other fields

        $.daoImages[daoUid] = dao.images;
        $.deployments[daoUid] = dao.deployments;
        $.daoParameters[daoUid] = dao.params;

        { // ------------------------- funding
            for (uint i; i < dao.funding.length; i++) {
                segment3.funding.push(dao.funding[i].fundingType);
                $.funding[HostLib.getKey(daoUid, uint(dao.funding[i].fundingType))] = dao.funding[i];
            }
        }

        { // ------------------------- vesting
            uint countVesting = uint32(dao.vesting.length);
            segment3.countVesting = countVesting;

            for (uint i; i < dao.vesting.length; i++) {
                $.vesting[HostLib.getIndexKey(daoUid, i)] = dao.vesting[i];
            }
        }

        HostActionsLib._finalizeDaoCreation($, dao.symbol, dao.name, daoUid);
    }
}
