// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMintedERC20} from "./IMintedERC20.sol";
import {IRefundableToken} from "./IRefundableToken.sol";

interface ITgeToken is IERC20, IERC20Metadata, IMintedERC20, IRefundableToken {
    /// @notice Id of DAO to which the token belongs
    function daoUid() external view returns (uint);
}
