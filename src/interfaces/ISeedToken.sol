// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMintedERC20} from "../interfaces/IMintedERC20.sol";

interface ISeedToken is IERC20, IMintedERC20 {

    error NonTransferable();

    /// @notice Get voting power of specific user
    /// @dev Support of Snapshot
    /// @param user_ Address of the user
    /// @return votes Voting power of the user
    function getVotes(address user_) external view returns (uint votes);

    /// @notice Burn tokens from specific address by Authority on refund event
    /// @param from Address to burn tokens from
    /// @param value Amount of tokens to burn
    function burnOnRefund(address from, uint value) external;

}
