// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IRefundableToken} from "./IRefundableToken.sol";
import {IMintedERC20} from "./IMintedERC20.sol";

interface ISeedToken is IERC20, IERC20Metadata, IMintedERC20, IRefundableToken {
    error NonTransferable();

    /// @notice Id of DAO to which the token belongs
    function daoUid() external view returns (uint);

    /// @notice Get voting power of specific user
    /// @dev Support of Snapshot
    /// @param user_ Address of the user
    /// @return votes Voting power of the user
    function getVotes(address user_) external view returns (uint votes);

    /// @notice Transfer given {amount} of {token} from balance to {to} address
    /// @custom:restricted Host only
    /// @param token Address of the token to transfer
    /// @param to Address to transfer tokens to
    /// @param amount Amount of tokens to transfer
    function transferTo(address token, address to, uint amount) external;
}
