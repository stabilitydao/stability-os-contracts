// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {Proxy} from "../../core/proxy/Proxy.sol";
import {SeedToken} from "../../tokenomics/SeedToken.sol";
import {TgeToken} from "../../tokenomics/TgeToken.sol";
import {IControllable2} from "../../interfaces/IControllable2.sol";

library OsDeployLib {
    function deploySeedToken(
        address accessManager,
        string memory token_,
        string memory symbol_
    ) external returns (address) {
        address logic = address(new SeedToken());

        // todo refactoring use factory

        Proxy proxy = new Proxy();
        proxy.initProxy(logic);

        IControllable2(address(proxy)).initialize(accessManager, abi.encode(token_, symbol_));
        return address(proxy);
    }

    function deployTgeToken(
        address accessManager,
        string memory token_,
        string memory symbol_
    ) external returns (address) {
        address logic = address(new TgeToken());

        // todo refactoring use factory

        Proxy proxy = new Proxy();
        proxy.initProxy(logic);

        IControllable2(address(proxy)).initialize(accessManager, abi.encode(token_, symbol_));
        return address(proxy);
    }
}
