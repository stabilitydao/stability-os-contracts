// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
import {MockERC20} from "@solady/../test/utils/mocks/MockERC20.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {SeedToken} from "../../../src/tokenomics/SeedToken.sol";
import {TgeToken} from "../../../src/tokenomics/TgeToken.sol";

/// @dev Set of host-setup-related functions ready to be used in integration tests
library HostSetupLib {
    /// @notice todo Use real asset instead mocked
    function getExchangeAssets(
        uint /*chainId*/
    ) internal returns (address exchangeAssets) {
        MockERC20 asset = new MockERC20("Exchange Asset USD", "USD", 8);
        return address(asset);
    }

    function setupHostSettings(EngineLib.ChainConfig memory core) internal {
        IHost.HostSettings memory settings = getDefaultHostSettings();
        core.host.setSettings(settings);
    }

    function setupHostChainSettings(uint chainId, EngineLib.ChainConfig memory core) internal {
        IHost.HostChainSettings memory settings;
        settings.dataReader = address(core.dataReader);
        settings.exchangeAsset = getExchangeAssets(chainId);
        settings.hostBridge = address(core.hostBridge);
        settings.timelock = 18 hours;

        core.host.setChainSettings(settings);
    }

    function getDefaultHostSettings() internal pure returns (IHost.HostSettings memory settings) {
        settings = IHost.HostSettings({
            priceDao: 100e6,
            fundingFee: 1000e8,
            minNameLength: 1,
            maxNameLength: 20,
            minSymbolLength: 1,
            maxSymbolLength: 7,
            minVePeriod: 14,
            maxVePeriod: 365 * 4,
            minPvPFee: 10e5,
            maxPvPFee: 100e5,
            minFunding: 100e6,
            minFundingDuration: 1 days,
            maxFundingDuration: 360 days,
            minFundingRaise: 1000e8, // 3 + 8
            maxFundingRaise: 1e20, // 12 + 8
            minVestingNameLen: 1,
            maxVestingNameLen: 20,
            minVestingDuration: 10 days,
            maxVestingDuration: 365 * 10 days,
            minCliff: 15 days,
            minInceptionDuration: 0 // 1 hours - 3 days
        });
    }

    function setTokenImplementations(EngineLib.ChainConfig memory core) internal {
        core.host.setContractImplementation(uint(IHost.ContractKinds.SEED_TOKEN_1), address(new SeedToken()));
        core.host.setContractImplementation(uint(IHost.ContractKinds.TGE_TOKEN_2), address(new TgeToken()));
    }
}
