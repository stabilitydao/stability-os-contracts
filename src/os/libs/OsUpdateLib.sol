// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenomics} from "../../interfaces/ITokenomics.sol";

/// @notice Validation and update logic
library OsUpdateLib {
    //region -------------------------------------- Data types

    //endregion -------------------------------------- Data types

    //region -------------------------------------- Actions
    function validate(
        ITokenomics.DaoData memory dao,
        ITokenomics.Activity[] memory activity,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding
    ) internal view {
        // todo implement validation logic
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Internal utils

    //endregion -------------------------------------- Internal utils


}