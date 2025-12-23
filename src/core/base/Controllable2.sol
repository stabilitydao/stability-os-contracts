// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SlotsLib} from "../libs/SlotsLib.sol";
import {IControllable2} from "../../interfaces/IControllable2.sol";
import {IPlatform} from "../../interfaces/IPlatform.sol";
import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

/// @dev Base core contract.
///      It store an immutable platform proxy address in the storage and provides access control to inherited contracts.
/// @author Alien Deployer (https://github.com/a17)
/// @author 0xhokugava (https://github.com/0xhokugava)
abstract contract Controllable2 is Initializable, AccessManagedUpgradeable, IControllable2, ERC165 {
    using SlotsLib for bytes32;

    string public constant CONTROLLABLE_VERSION = "1.0.0";

    bytes32 internal constant _CREATED_BLOCK_SLOT = bytes32(uint(keccak256("eip1967.controllable.created_block")) - 1);

    /// @dev Prevent implementation init
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize contract after setup it as proxy implementation
    ///         Save block.timestamp in the "created" variable
    /// @dev Use it only once after first logic setup
    /// @param authority_ Access Manager address
    //slither-disable-next-line naming-convention
    function __Controllable_init(address authority_) internal onlyInitializing {
        require(authority_ != address(0), IncorrectZeroArgument());
        AccessManagedUpgradeable.__AccessManaged_init(authority_);
        _CREATED_BLOCK_SLOT.set(block.number);
        emit ContractInitialized(authority_, block.timestamp, block.number);
    }

    /// @inheritdoc IControllable2
    function createdBlock() external view override returns (uint) {
        return _CREATED_BLOCK_SLOT.getUint();
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IControllable2).interfaceId || super.supportsInterface(interfaceId);
    }
}
