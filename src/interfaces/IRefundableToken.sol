// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMintedERC20} from "../interfaces/IMintedERC20.sol";

interface IRefundableToken is IERC20, IMintedERC20 {
    /// @notice Burn tokens from specific address by Authority and refund underlying asset back to the user
    /// @custom:restricted OS only
    /// @param from Address to burn tokens from
    /// @param amount Amount of tokens to burn
    /// @param asset Address of the underlying asset to refund
    /// @param receiver Address to send refunded asset to
    function refund(address from, uint amount, address asset, address receiver) external;
}
