// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Hosted} from "../base/Hosted.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {ITgeToken} from "../interfaces/ITgeToken.sol";
import {IMintedERC20} from "../interfaces/IMintedERC20.sol";
import {IRefundableToken} from "../interfaces/IRefundableToken.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IDataReader} from "../interfaces/IDataReader.sol";
import {IAuthority} from "../interfaces/IAuthority.sol";

contract TgeToken is ITgeToken, Hosted, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable {
    using SafeERC20 for IERC20;

    /// @inheritdoc IHosted
    string public constant VERSION = "1.0.0";

    // keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.TgeToken")) - 1)) & ~bytes32(uint(0xff));
    bytes32 internal constant TGE_TOKEN_STORAGE_LOCATION =
        0xfb46caaef7d9417e7aaa9038decbe519bdc48c2b702b54c518cab049b1114a00;

    /// @custom:storage-location erc7201:stability.host-contracts.TgeToken
    struct TgeTokenStorage {
        /// @notice Unique id of the DAO to which the token belongs
        uint daoUid;
    }

    /// @inheritdoc IHosted
    function initialize(address authority_, bytes memory payload) public payable initializer {
        TgeTokenStorage storage $ = _tgeTokenStorage();
        $.daoUid = abi.decode(payload, (uint));

        __Hosted_init(authority_);
        __ERC20_init("", "");
        __ERC20Burnable_init();
        __ERC20Permit_init("TgeToken"); // todo Token is NOT transferable => ERC20PermitUpgradeable is not needed???
    }

    function daoUid() public view returns (uint) {
        TgeTokenStorage storage $ = _tgeTokenStorage();
        return $.daoUid;
    }

    /// @inheritdoc IMintedERC20
    function mint(address to, uint amount) public restricted {
        _mint(to, amount);
    }

    /// @inheritdoc ERC20Upgradeable
    function name() public view override returns (string memory) {
        return IDataReader(IHost(IAuthority(authority()).HOST()).dataReader())
            .getTokenName(daoUid(), uint(IHost.NamingTokenKind.TGE_1));
    }

    /// @inheritdoc ERC20Upgradeable
    function symbol() public view override returns (string memory) {
        return IDataReader(IHost(IAuthority(authority()).HOST()).dataReader())
            .getTokenSymbol(daoUid(), uint(IHost.NamingTokenKind.TGE_1));
    }

    /// @inheritdoc IRefundableToken
    function refund(address from, uint amount, address asset, address receiver) external restricted {
        // authority no need allowance for burning
        super._burn(from, amount);
        IERC20(asset).safeTransfer(receiver, amount);
    }

    function _tgeTokenStorage() private pure returns (TgeTokenStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := TGE_TOKEN_STORAGE_LOCATION
        }
    }
}
