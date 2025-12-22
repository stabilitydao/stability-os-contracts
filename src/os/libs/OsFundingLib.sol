// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOS} from "../../interfaces/IOS.sol";
import {ITokenomics, IDAOUnit} from "../../interfaces/ITokenomics.sol";
import {OsLib} from "./OsLib.sol";
import {console} from "forge-std/console.sol";
import {IMintedERC20} from "../../interfaces/IMintedERC20.sol";
import {OsEncodingLib} from "./OsEncodingLib.sol";
import {IBurnableERC20} from "../../interfaces/IBurnableERC20.sol";

library OsFundingLib {
    using SafeERC20 for IERC20;

    /// @notice Fund DAO in the current funding round
    function fund(string calldata daoSymbol, uint amount) external {
        // todo not reentrancy
        require(amount != 0, IOS.ZeroAmount()); // todo settings.minFunding

        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];

        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;

        if (phase == ITokenomics.LifecyclePhase.SEED_1) {
            ITokenomics.Funding storage seed = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];

            require(seed.raised + amount < seed.maxRaise, IOS.RaiseMaxExceed());

            // transfer amount of exchangeAsset to seedToken contract
            address seedToken = $.deployments[daoUid].seedToken;
            IERC20($.osChainSettings[0].exchangeAsset).safeTransferFrom(msg.sender, seedToken, amount);

            seed.raised += amount;

            // mint seedToken to user
            IMintedERC20(seedToken).mint(msg.sender, amount);

            emit IOS.DaoFunded(daoSymbol, msg.sender, amount, uint8(ITokenomics.FundingType.SEED_0));
        } else if (phase == ITokenomics.LifecyclePhase.TGE_4) {
            ITokenomics.Funding storage tge = $.funding[OsLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

            require(tge.raised + amount < tge.maxRaise, IOS.RaiseMaxExceed());

            // transfer amount of exchangeAsset to tgeToken contract
            address tgeToken = $.deployments[daoUid].tgeToken;
            IERC20($.osChainSettings[0].exchangeAsset).safeTransferFrom(msg.sender, tgeToken, amount);

            tge.raised += amount;

            // record msg.sender as funder with amount
            IMintedERC20(tgeToken).mint(msg.sender, amount);

            emit IOS.DaoFunded(daoSymbol, msg.sender, amount, uint8(ITokenomics.FundingType.TGE_1));
        } else {
            revert IOS.NotFundingPhase();
        }
    }

    /// @notice Refund funding to the SEED/TGE token holders if funding round failed
    /// Anybody can call this function to refund his own tokens
    /// SEED token can be returned only on SEED_FAILED phase
    /// TGE token can be returned only on DEVELOPMENT phase
    function refund(string calldata daoSymbol) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];
        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;

        address asset = $.osChainSettings[0].exchangeAsset;
        if (phase == ITokenomics.LifecyclePhase.SEED_FAILED_2) {
            address seedToken = $.deployments[daoUid].seedToken;
            _refundFunding(daoSymbol, ITokenomics.FundingType.SEED_0, msg.sender, seedToken, asset, false);
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            address tgeToken = $.deployments[daoUid].tgeToken;
            _refundFunding(daoSymbol, ITokenomics.FundingType.TGE_1, msg.sender, tgeToken, asset, false);
        } else {
            revert IOS.NotRefundPhase();
        }
    }

    /// @notice Refund funding to the SEED/TGE token holders if funding round failed
    /// Anybody can call this function to make refund of first {limit} token holders
    /// SEED token can be returned only on SEED_FAILED phase
    /// TGE token can be returned only on DEVELOPMENT phase
    function refundFor(string calldata daoSymbol, address[] memory receivers) external {
        OsLib.OsStorage storage $ = OsLib.getOsStorage();
        uint daoUid = $.daoUids[daoSymbol];
        ITokenomics.LifecyclePhase phase = $.daos[daoUid].phase;

        address asset = $.osChainSettings[0].exchangeAsset;
        if (phase == ITokenomics.LifecyclePhase.SEED_FAILED_2) {
            address seedToken = $.deployments[daoUid].seedToken;
            for (uint i; i < receivers.length; i++) {
                _refundFunding(daoSymbol, ITokenomics.FundingType.SEED_0, receivers[i], seedToken, asset, true);
            }
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            address tgeToken = $.deployments[daoUid].tgeToken;
            for (uint i; i < receivers.length; i++) {
                _refundFunding(daoSymbol, ITokenomics.FundingType.TGE_1, receivers[i], tgeToken, asset, true);
            }
        } else {
            revert IOS.NotRefundPhase();
        }
    }

    function _refundFunding(
        string calldata daoSymbol,
        ITokenomics.FundingType fundingType_,
        address receiver,
        address fundingToken,
        address exchangeAsset,
        bool skipOnZeroBalance
    ) internal {
        uint balance = IERC20(fundingToken).balanceOf(receiver);
        if (balance == 0) {
            require(skipOnZeroBalance, IOS.ZeroBalance());
        } else {
            // burn SEED tokens
            // todo IBurnableERC20(seedToken).burn(receiver, balance);

            // todo decrease raised amount in funding round: do we need merkl?

            // transfer exchangeAsset back to receiver
            IERC20(exchangeAsset).safeTransferFrom(fundingToken, receiver, balance);

            emit IOS.DaoRefunded(daoSymbol, receiver, balance, uint8(fundingType_));
        }
    }
}
