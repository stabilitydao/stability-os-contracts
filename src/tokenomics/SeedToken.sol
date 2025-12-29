// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Controllable2} from "../core/base/Controllable2.sol";
import {IControllable2} from "../interfaces/IControllable2.sol";
import {ISeedToken} from "../interfaces/ISeedToken.sol";
import {IMintedERC20} from "../interfaces/IMintedERC20.sol";

contract SeedToken is
    ISeedToken,
    Controllable2,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable
{
    /// @inheritdoc IControllable2
    string public constant VERSION = "1.0.0";

    /// @inheritdoc IControllable2
    function initialize(address authority_, bytes memory payload) public initializer {
        (string memory _name, string memory _symbol) = abi.decode(payload, (string, string));

        __Controllable_init(authority_);
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        __ERC20Permit_init(_name);
    }

    /// @inheritdoc IMintedERC20
    function mint(address to, uint amount) public restricted {
        _mint(to, amount);
    }

    /// @inheritdoc ISeedToken
    function burnOnRefund(address from, uint value) public override restricted {
        // authority no need allowance for burning
        super._burn(from, value);
    }

    /// @inheritdoc ISeedToken
    function getVotes(address user_) public view returns (uint votes) {
        votes = balanceOf(user_);
    }

    /// @dev The token is not transferable, only minting and burning is allowed
    function _update(address from, address to, uint value) internal override {
        require(from == address(0) || to == address(0), NonTransferable());

        super._update(from, to, value);
    }

}
