// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IMintedERC20} from "../interfaces/IMintedERC20.sol";
import {Controllable2} from "../core/base/Controllable2.sol";
import {IControllable2} from "../interfaces/IControllable2.sol";
import {IToken} from "../interfaces/IToken.sol";

contract Token is
    IToken,
    Controllable2,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    IMintedERC20
{
    /// @inheritdoc IControllable2
    string public constant VERSION = "1.0.0";

    /// @inheritdoc IControllable2
    function initialize(address authority_) public initializer {
        __Controllable_init(authority_);
        __ERC20_init("TODO", "TODO");
        __ERC20Burnable_init();
        __ERC20Permit_init("TODO");
    }

    /// @inheritdoc IToken
    function initialize(address authority_, string memory name_, string memory symbol_) public initializer {
        __Controllable_init(authority_);
        __ERC20_init(name_, symbol_);
        __ERC20Burnable_init();
        __ERC20Permit_init(symbol_);
    }

    /// @inheritdoc IMintedERC20
    function mint(address to, uint amount) public restricted {
        _mint(to, amount);
    }
}
