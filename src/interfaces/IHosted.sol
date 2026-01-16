// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

/// @dev Base core interface implemented by most host-platform contracts.
interface IHosted is IAccessManaged {
    error IncorrectZeroArgument();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance(uint actualBalance, uint requiredBalance);
    event ContractInitialized(address authority, uint ts, uint block);

    /// @notice Initialize contract with authority and payload
    /// @param authority_ Address of authority contract (Access manager)
    /// @param payload Additional initialization payload (encoded set of initialization params)
    function initialize(address authority_, bytes memory payload) external;

    /// @notice Version of contract implementation
    /// @dev SemVer scheme MAJOR.MINOR.PATCH
    //slither-disable-next-line naming-convention
    function VERSION() external view returns (string memory);

    /// @notice Block number when contract was initialized
    function createdBlock() external view returns (uint);
}
