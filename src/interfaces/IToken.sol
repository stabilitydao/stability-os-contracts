// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IToken is IERC20 {
    /// @notice Initialize the token contract
    /// @param authority_ Address of Access Manager
    /// @param name_ Name of the token
    /// @param symbol_ Symbol of the token
    function initialize(address authority_, string memory name_, string memory symbol_) external;
}
