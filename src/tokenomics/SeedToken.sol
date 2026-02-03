// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Hosted} from "../base/Hosted.sol";
import {IAuthority} from "../interfaces/IAuthority.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IMintedERC20} from "../interfaces/IMintedERC20.sol";
import {IRefundableToken} from "../interfaces/IRefundableToken.sol";
import {ISeedToken} from "../interfaces/ISeedToken.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IDataReader} from "../interfaces/IDataReader.sol";

contract SeedToken is ISeedToken, Hosted, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable {
    using SafeERC20 for IERC20;

    /// @inheritdoc IHosted
    string public constant VERSION = "1.0.0";

    // keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.SeedToken")) - 1)) & ~bytes32(uint(0xff));
    bytes32 internal constant SEED_TOKEN_STORAGE_LOCATION =
        0x476ed2813cc08bac9ef6a1c6101c6a17336ecaef2a76beb9afac3acf4fef2f00;

    /// @custom:storage-location erc7201:stability.host-contracts.SeedToken
    struct SeedTokenStorage {
        /// @notice Unique id of the DAO to which the token belongs
        uint daoUid;
    }

    /// @inheritdoc IHosted
    function initialize(address authority_, bytes memory payload) public payable initializer {
        SeedTokenStorage storage $ = _seedTokenStorage();
        $.daoUid = abi.decode(payload, (uint));

        __Hosted_init(authority_);
        __ERC20_init("", "");
        __ERC20Burnable_init();
        __ERC20Permit_init("SeedToken"); // todo Token is NOT transferable => ERC20PermitUpgradeable is not needed???
    }

    function daoUid() public view returns (uint) {
        SeedTokenStorage storage $ = _seedTokenStorage();
        return $.daoUid;
    }

    /// @inheritdoc IMintedERC20
    function mint(address to, uint amount) public restricted {
        _mint(to, amount);
    }

    /// @inheritdoc IRefundableToken
    function refund(address from, uint amount, address asset, address receiver) external restricted {
        // authority no need allowance for burning
        super._burn(from, amount);
        IERC20(asset).safeTransfer(receiver, amount);
    }

    /// @inheritdoc ISeedToken
    function getVotes(address user_) public view returns (uint votes) {
        votes = balanceOf(user_);
    }

    /// @inheritdoc ISeedToken
    function transferTo(address token, address to, uint amount) external restricted {
        require(amount != 0, ZeroAmount());
        require(to != address(0), ZeroAddress());
        uint balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, InsufficientBalance(balance, amount));

        IERC20(token).safeTransfer(to, amount);
    }

    /// @inheritdoc ERC20Upgradeable
    function name() public view override returns (string memory) {
        return IDataReader(IHost(IAuthority(authority()).HOST()).dataReader())
            .getTokenName(daoUid(), uint(IHost.NamingTokenKind.SEED_0));
    }

    /// @inheritdoc ERC20Upgradeable
    function symbol() public view override returns (string memory) {
        return IDataReader(IHost(IAuthority(authority()).HOST()).dataReader())
            .getTokenSymbol(daoUid(), uint(IHost.NamingTokenKind.SEED_0));
    }

    /// @dev The token is not transferable, only minting and burning is allowed
    function _update(address from, address to, uint value) internal override {
        require(from == address(0) || to == address(0), NonTransferable());

        super._update(from, to, value);
    }

    function _seedTokenStorage() private pure returns (SeedTokenStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := SEED_TOKEN_STORAGE_LOCATION
        }
    }
}
