// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HostLib} from "./HostLib.sol";
import {IAuthority} from "../interfaces/IAuthority.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {ISeedToken} from "../interfaces/ISeedToken.sol";
import {IRefundableToken} from "../interfaces/IRefundableToken.sol";
import {IMintedERC20} from "../interfaces/IMintedERC20.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IUUPSUpgradable} from "../interfaces/IUUPSUpgradable.sol";
import {HostProxyLib} from "./HostProxyLib.sol";
import {AccessRolesLib} from "./AccessRolesLib.sol";

/// @notice Library for deploying any contracts required by DAOs
library HostDeployLib {
    /// @notice Deploys the Seed Token contract for a DAO
    function deploySeedToken(
        HostLib.HostStorage storage $,
        uint daoUid,
        address authority_
    ) internal returns (address seedToken) {
        bytes32 seed = $.salt[HostLib.getKey(daoUid, uint16(IDAOData.ContractIndices.SEED_TOKEN_1))];
        seedToken =
            HostProxyLib.deployContract(seed, uint(IHost.ContractKinds.SEED_TOKEN_1), abi.encode(daoUid), authority_);
        _setupSeedToken(seedToken, authority_);
        _setupUpgradable(seedToken, authority_);
    }

    /// @notice Deploys the TGE Token contract for a DAO
    function deployTgeToken(
        HostLib.HostStorage storage $,
        uint daoUid,
        address authority_
    ) internal returns (address tgeToken) {
        bytes32 seed = $.salt[HostLib.getKey(daoUid, uint16(IDAOData.ContractIndices.TGE_TOKEN_2))];
        tgeToken =
            HostProxyLib.deployContract(seed, uint(IHost.ContractKinds.TGE_TOKEN_2), abi.encode(daoUid), authority_);
        _setupTgeToken(tgeToken, authority_);
        _setupUpgradable(tgeToken, authority_);
    }

    /// @dev set up HOST as operator for all restricted functions
    function _setupSeedToken(address seedToken, address authority_) internal {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = bytes4(IMintedERC20.mint.selector);
        selectors[1] = bytes4(IRefundableToken.refund.selector);
        selectors[2] = bytes4(ISeedToken.transferTo.selector);

        try IAuthority(authority_).setTargetFunctionRole(seedToken, selectors, AccessRolesLib.HOST_TOKEN_MINTER) {} catch {}
        // todo remove it. execute while deploy
        try IAuthority(authority_).grantRole(AccessRolesLib.HOST_TOKEN_MINTER, address(this), 0) {} catch {}
    }

    /// @dev set up HOST as operator for all restricted functions
    function _setupTgeToken(address tgeToken, address authority_) internal {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(IMintedERC20.mint.selector);
        selectors[1] = bytes4(IRefundableToken.refund.selector);

        _setSelectors(authority_, tgeToken, selectors, AccessRolesLib.HOST_TOKEN_MINTER);
    }

    /// @dev set up HOST as operator for all restricted functions
    function _setupUpgradable(address target_, address authority_) internal {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(IUUPSUpgradable.upgradeToAndCall.selector);

        _setSelectors(authority_, target_, selectors, AccessRolesLib.CONTRACTS_UPGRADER);
    }

    function _setSelectors(address authority_, address target_, bytes4[] memory selectors, uint64 role) internal {
        try IAuthority(authority_).setTargetFunctionRole(target_, selectors, role) {} catch {}
        // todo remove it. execute while deploy
        try IAuthority(authority_).grantRole(role, address(this), 0) {} catch {}
    }
}
