// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Test.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {BridgeTestLib} from "../../utils/BridgeTestLib.sol";

library BridgeSetupLib {
    /// @dev Set to 0 for immediate switch, or block number for gradual migration
    uint private constant GRACE_PERIOD = 0;

    uint32 internal constant MAX_MESSAGE_SIZE = 256;

    /// @dev Minimum block confirmations to wait on Sonic
    uint64 internal constant MIN_BLOCK_CONFIRMATIONS_SEND = 15;

    /// @dev Minimum block confirmations required on Avalanche
    uint64 internal constant MIN_BLOCK_CONFIRMATIONS_RECEIVE = 10;

    /// @dev By default shared decimals (min decimals at all chains) is 6 for STBL
    uint internal constant SHARED_DECIMALS = 6;

    function setUpOAppsSingleDVN(
        Vm vm,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        address srcDvn,
        address targetDvn
    ) internal {
        // ------------------- Set up sending chain for Sonic:Plasma
        vm.selectFork(src.fork);
        vm.startPrank(src.delegator);

        {
            address[] memory requiredDVNs = new address[](1);
            requiredDVNs[0] = srcDvn;

            BridgeTestLib._setupOAppOnChain(
                src,
                target.endpointId,
                requiredDVNs,
                MIN_BLOCK_CONFIRMATIONS_SEND,
                MAX_MESSAGE_SIZE,
                MIN_BLOCK_CONFIRMATIONS_RECEIVE
            );
        }
        vm.stopPrank();

        // ------------------- Set up sending chain for Avalanche:Plasma
        vm.selectFork(target.fork);
        vm.startPrank(target.delegator);

        {
            address[] memory requiredDVNs = new address[](1);
            requiredDVNs[0] = targetDvn;

            BridgeTestLib._setupOAppOnChain(
                target,
                src.endpointId,
                requiredDVNs,
                MIN_BLOCK_CONFIRMATIONS_SEND,
                MAX_MESSAGE_SIZE,
                MIN_BLOCK_CONFIRMATIONS_RECEIVE
            );
        }

        vm.stopPrank();
    }
}
