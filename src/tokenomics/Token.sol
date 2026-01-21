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
import {Hosted} from "../base/Hosted.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IToken} from "../interfaces/IToken.sol";

contract Token is IToken, Hosted, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable, IMintedERC20 {
    /// @inheritdoc IHosted
    string public constant VERSION = "1.0.0";

    /// @inheritdoc IHosted
    function initialize(address authority_, bytes memory payload) public initializer {
        (string memory _name, string memory _symbol) = abi.decode(payload, (string, string));

        __Hosted_init(authority_);
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        __ERC20Permit_init(_name);
    }

    /// @inheritdoc IMintedERC20
    function mint(address to, uint amount) public restricted {
        _mint(to, amount);
    }
}
