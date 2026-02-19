// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
import {MockERC20} from "@solady/../test/utils/mocks/MockERC20.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";

/// @dev Set of host-setup-related functions ready to be used in integration tests
library HostSetupUsesCaseLib {
    /// @notice todo Use real asset instead mocked
    function getExchangeAssets(
        uint /*chainId*/
    ) internal returns (address exchangeAssets) {
        MockERC20 asset = new MockERC20("Exchange Asset USD", "USD", 8);
        return address(asset);
    }

    function setupHostSettings(EngineLib.Core memory core) internal {
        IHost.HostSettings memory settings = getDefaultHostSettings();
        core.host.setSettings(settings);
    }

    function setupHostChainSettings(uint chainId, EngineLib.Core memory core) internal {
        IHost.HostChainSettings memory settings;
        settings.dataReader = address(core.dataReader);
        settings.exchangeAsset = getExchangeAssets(chainId);
        settings.hostBridge = address(core.hostBridge);
        settings.timelock = 18 hours;

        core.host.setChainSettings(settings);
    }

    function getDefaultHostSettings() internal pure returns (IHost.HostSettings memory settings) {
        settings = IHost.HostSettings({
            priceDao: 1000e8,
            fundingFee: 1000e8,
            minNameLength: 1,
            maxNameLength: 20,
            minSymbolLength: 1,
            maxSymbolLength: 7,
            minVePeriod: 14,
            maxVePeriod: 365 * 4,
            minPvPFee: 10e5,
            maxPvPFee: 100e5,
            minFunding: 100e8, // todo
            minFundingDuration: 1 days,
            maxFundingDuration: 180 days,
            minFundingRaise: 1000e8, // 3 + 8
            maxFundingRaise: 1e20, // 12 + 8
            minVestingNameLen: 1,
            maxVestingNameLen: 20,
            minVestingDuration: 10 days,
            maxVestingDuration: 365 * 4 days,
            minCliff: 15 days,
            minInceptionDuration: 17 days // todo
        });
    }
}
