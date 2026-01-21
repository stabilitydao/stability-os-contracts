// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SlotsLib} from "../libs/SlotsLib.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

/// @dev Base core contract.
///      It store an immutable platform proxy address in the storage and provides access control to inherited contracts.
/// @author Alien Deployer (https://github.com/a17)
/// @author 0xhokugava (https://github.com/0xhokugava)
abstract contract Hosted is Initializable, UUPSUpgradeable, AccessManagedUpgradeable, IHosted, ERC165 {
    using SlotsLib for bytes32;

    string public constant HOSTED_VERSION = "1.0.0";

    /// @dev "controllable" was not changed to "hosted" to keep compatibility with existing contracts
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
    function __Hosted_init(address authority_) internal onlyInitializing {
        require(authority_ != address(0), IncorrectZeroArgument());
        AccessManagedUpgradeable.__AccessManaged_init(authority_);
        __UUPSUpgradeable_init();
        _CREATED_BLOCK_SLOT.set(block.number);
        emit ContractInitialized(authority_, block.timestamp, block.number);
    }

    /// @inheritdoc IHosted
    function createdBlock() external view override returns (uint) {
        return _CREATED_BLOCK_SLOT.getUint();
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IHosted).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Authorize upgrade function through authority
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @notice Don't allow to use old Proxy.upgrade function. Use Proxy.upgradeTo instead
    function platform() public pure returns (address) {
        revert("platform is deprecated");
    }
}
