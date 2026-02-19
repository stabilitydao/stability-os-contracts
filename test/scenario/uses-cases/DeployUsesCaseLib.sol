// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {DeployIntentsLib} from "../commands/DeployIntentsLib.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {EngineLib} from "../engine/EngineLib.sol";

/// @dev Set of functions ready to be used in uses-cases
library DeployUsesCaseLib {
    /// @dev Deploy authority. Assume that proxy factory is already deployed.
    function deployAuthority(EngineLib.BaseContext memory bc) internal returns (IAuthority) {
        IProxyFactory proxyFactory = IProxyFactory(bc.configDeployed.get(bc.chainId, "PROXY_FACTORY").toAddress());

        // @dev 1. Proxy factory owner deploys authority and sets up permissions for it
        return IAuthority(
            DeployIntentsLib.deployAuthority(
                DeployIntentsLib.buildIntentDeployAuthority(bc.config, bc.chainId, address(proxyFactory))
            )
        );
    }

    /// @dev Deploy first host on Ethereum. Assume that there are no other hosts on other chains.
    function deployFirstHost(EngineLib.BaseContext memory bc, address authority) internal returns (IHost) {
        /// @dev Use init params for first Host on initial chain
        return deployHost(
            bc,
            authority,
            IHost.HostInitPayload({
                usedSymbols: new string[](0), daoHostSymbol: "", daoHostUid: 0, hostVersion: "2026.00.00"
            })
        );
    }

    /// @dev Deploy host on not initial chain.
    /// @param init It should have data from already deployed host instances.
    function deployHost(
        EngineLib.BaseContext memory bc,
        address authority,
        IHost.HostInitPayload memory init
    ) internal returns (IHost) {
        /// @dev 1. Build intent from config
        DeployIntentsLib.IntentDeployHostIn memory intent = DeployIntentsLib.buildIntentDeployHost(bc.config, bc.chainId, authority, init);

        /// @dev 2. Deploy host
        return IHost(DeployIntentsLib.deployHost(intent));
    }

    /// @dev Deploy host bridge for the given host
    function deployHostBridge(EngineLib.BaseContext memory bc, address host) internal returns (IHostBridge) {
        IProxyFactory proxyFactory = IProxyFactory(bc.configDeployed.get(bc.chainId, "PROXY_FACTORY").toAddress());
        address proxyFactoryOwner = IOwnable(address(proxyFactory)).owner();

        /// @dev 1. Build intent from config
        DeployIntentsLib.IntentDeployHostBridgeIn memory intent =
            DeployIntentsLib.buildIntentDeployHostBridge(bc.config, bc.chainId, proxyFactoryOwner, host);

        /// @dev 2. Deploy host
        return DeployIntentsLib.deployHostBridge(intent);
    }
}
