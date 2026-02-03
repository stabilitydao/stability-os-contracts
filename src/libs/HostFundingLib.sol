// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHost} from "../interfaces/IHost.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";
import {HostLib} from "./HostLib.sol";
import {IMintedERC20} from "../interfaces/IMintedERC20.sol";
import {IHosted} from "../interfaces/IHosted.sol";
import {IRefundableToken} from "../interfaces/IRefundableToken.sol";
import {HostConfigLib} from "./HostConfigLib.sol";

library HostFundingLib {
    using SafeERC20 for IERC20;

    /// @notice Fund DAO in the current funding round
    function fund(string calldata symbol, uint amount) external {
        // todo not reentrancy
        require(amount != 0, IHosted.ZeroAmount()); // todo settings.minFunding

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);

        ITokenomics.LifecyclePhase phase = $.segment2[daoUid].phase;

        if (phase == ITokenomics.LifecyclePhase.SEED_1) {
            ITokenomics.Funding storage seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];

            require(seed.raised + amount < seed.maxRaise, IHost.RaiseMaxExceed());

            // transfer amount of exchangeAsset to seedToken contract
            address seedToken = $.deployments[daoUid].seedToken;
            IERC20(HostConfigLib.getHostChainSettings().exchangeAsset).safeTransferFrom(msg.sender, seedToken, amount);

            seed.raised += amount;

            // mint seedToken to user
            IMintedERC20(seedToken).mint(msg.sender, amount);

            emit IHost.DaoFunded(daoUid, msg.sender, amount, uint8(ITokenomics.FundingType.SEED_0));
        } else if (phase == ITokenomics.LifecyclePhase.TGE_4) {
            ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

            require(tge.raised + amount < tge.maxRaise, IHost.RaiseMaxExceed());

            // transfer amount of exchangeAsset to tgeToken contract
            address tgeToken = $.deployments[daoUid].tgeToken;
            IERC20(HostConfigLib.getHostChainSettings().exchangeAsset).safeTransferFrom(msg.sender, tgeToken, amount);

            tge.raised += amount;

            // record msg.sender as funder with amount
            IMintedERC20(tgeToken).mint(msg.sender, amount);

            emit IHost.DaoFunded(daoUid, msg.sender, amount, uint8(ITokenomics.FundingType.TGE_1));
        } else {
            revert IHost.NotFundingPhase();
        }
    }

    /// @notice Refund funding to the SEED/TGE token holders if funding round failed
    /// Anybody can call this function to refund his own tokens
    /// SEED token can be returned only on SEED_FAILED phase
    /// TGE token can be returned only on DEVELOPMENT phase
    function refund(string calldata symbol) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);
        ITokenomics.LifecyclePhase phase = $.segment2[daoUid].phase;

        address asset = HostConfigLib.getHostChainSettings().exchangeAsset;
        if (phase == ITokenomics.LifecyclePhase.SEED_FAILED_2) {
            address seedToken = $.deployments[daoUid].seedToken;
            _refundFunding(symbol, ITokenomics.FundingType.SEED_0, msg.sender, seedToken, asset, false);
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            address tgeToken = $.deployments[daoUid].tgeToken;
            _refundFunding(symbol, ITokenomics.FundingType.TGE_1, msg.sender, tgeToken, asset, false);
        } else {
            revert IHost.NotRefundPhase();
        }
    }

    /// @notice Refund funding to the SEED/TGE token holders if funding round failed
    /// Anybody can call this function to make refund of first {limit} token holders
    /// SEED token can be returned only on SEED_FAILED phase
    /// TGE token can be returned only on DEVELOPMENT phase
    function refundFor(string calldata symbol, address[] memory receivers) external {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = HostLib.getDaoUid($, symbol);
        ITokenomics.LifecyclePhase phase = $.segment2[daoUid].phase;

        address asset = HostConfigLib.getHostChainSettings().exchangeAsset;
        if (phase == ITokenomics.LifecyclePhase.SEED_FAILED_2) {
            address seedToken = $.deployments[daoUid].seedToken;
            for (uint i; i < receivers.length; i++) {
                _refundFunding(symbol, ITokenomics.FundingType.SEED_0, receivers[i], seedToken, asset, true);
            }
        } else if (phase == ITokenomics.LifecyclePhase.DEVELOPMENT_3) {
            address tgeToken = $.deployments[daoUid].tgeToken;
            for (uint i; i < receivers.length; i++) {
                _refundFunding(symbol, ITokenomics.FundingType.TGE_1, receivers[i], tgeToken, asset, true);
            }
        } else {
            revert IHost.NotRefundPhase();
        }
    }

    function _refundFunding(
        string calldata symbol,
        ITokenomics.FundingType fundingType_,
        address receiver,
        address fundingToken,
        address exchangeAsset,
        bool skipOnZeroBalance
    ) internal {
        uint balance = IERC20(fundingToken).balanceOf(receiver);
        if (balance == 0) {
            require(skipOnZeroBalance, IHost.ZeroBalance());
        } else {
            HostLib.HostStorage storage $ = HostLib.getHostStorage();

            IRefundableToken(fundingToken).refund(receiver, balance, exchangeAsset, receiver);

            uint daoUid = HostLib.getDaoUid($, symbol);
            ITokenomics.Funding storage funding = $.funding[HostLib.getKey(daoUid, uint(fundingType_))];
            uint raised = funding.raised;
            funding.raised = raised > balance ? raised - balance : 0;

            emit IHost.DaoRefunded(daoUid, receiver, exchangeAsset, balance, uint8(fundingType_));
        }
    }
}
