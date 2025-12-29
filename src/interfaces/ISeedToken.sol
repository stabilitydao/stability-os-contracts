// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRefundableToken} from "./IRefundableToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMintedERC20} from "../interfaces/IMintedERC20.sol";

interface ISeedToken is IERC20, IMintedERC20, IRefundableToken {

    error NonTransferable();

    /// @notice Get voting power of specific user
    /// @dev Support of Snapshot
    /// @param user_ Address of the user
    /// @return votes Voting power of the user
    function getVotes(address user_) external view returns (uint votes);

    /// @notice Transfer given {amount} of {token} from balance to {to} address
    /// @custom:restricted OS only
    /// @param token Address of the token to transfer
    /// @param to Address to transfer tokens to
    /// @param amount Amount of tokens to transfer
    function transferTo(address token, address to, uint amount) external;

}
