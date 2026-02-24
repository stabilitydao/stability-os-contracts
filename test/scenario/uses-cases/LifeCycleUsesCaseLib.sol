// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
// import {PrintUtilsLib} from "../../utils/PrintUtilsLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vm} from "forge-std/Test.sol";
import {CommonUtilsLib} from "../../utils/CommonUtilsLib.sol";

/// @dev A DAO passes various stages of its life cycle
library LifeCycleUsesCaseLib {
    string internal constant HOST_DAO_SYMBOL = "HOST";
    string internal constant HOST_DAO_NAME = "DAO Host";

    /// @dev Move to INCEPTION phase of a DAO lifecycle starting from DRAFT phase.
    function moveToInceptionPhaseFromDraft(
        EngineLib.Context memory context,
        IDAOData.DaoData memory dao
    ) internal {
        context.core.host.changePhase(dao.symbol);
    }

    /// @dev Move to SEED phase of a DAO lifecycle starting from DRAFT phase.
    /// @param funders Assume that all funders already have enough balance of exchange asset to fund the DAO
    function moveToSeedPhaseFromDraft(
        Vm vm,
        EngineLib.Context memory context,
        IDAOData.DaoData memory dao,
        EngineLib.Funder[] memory funders
    ) internal {
        // ---------------------------- Move to inception
        moveToInceptionPhaseFromDraft(context, dao);

        // ---------------------------- Move to SEED
        CommonUtilsLib.skip(vm, dao.funding[0].start - block.timestamp + 1);
        context.core.host.changePhase(dao.symbol);

        // ---------------------------- Seeding
        uint duration = dao.funding[0].end - dao.funding[0].start;
        address exchangeAsset = context.core.host.getChainSettings().exchangeAsset;

        for (uint i; i < funders.length; ++i) {
            CommonUtilsLib.skip(vm, duration / (funders.length + 1)); // skip some time between fundings

            vm.prank(funders[i].user);
            IERC20(exchangeAsset).approve(address(context.core.host), funders[i].amount);

            vm.prank(funders[i].user);
            context.core.host.fund(dao.symbol, funders[i].amount);
        }
    }

    /// @dev Move to DEVELOPMENT phase of a DAO lifecycle starting from DRAFT phase.
    /// @param funders Assume that all funders already have enough balance of exchange asset to fund the DAO
    function moveToDevelopmentPhaseFromDraft(
        Vm vm,
        EngineLib.Context memory context,
        IDAOData.DaoData memory dao,
        EngineLib.Funder[] memory funders
    ) internal {
        moveToSeedPhaseFromDraft(vm, context, dao, funders);

        // ---------------------------- Seeding ends, move to Development phase
        CommonUtilsLib.skip(vm, dao.funding[0].end - block.timestamp + 1);
        context.core.host.changePhase(dao.symbol);

    }
}
