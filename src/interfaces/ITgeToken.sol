// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMintedERC20} from "../interfaces/IMintedERC20.sol";
import {IRefundableToken} from "../interfaces/IRefundableToken.sol";

interface ITgeToken is IERC20, IMintedERC20, IRefundableToken {}
