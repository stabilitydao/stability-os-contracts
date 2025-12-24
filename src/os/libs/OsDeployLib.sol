// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {Proxy} from "../../core/proxy/Proxy.sol";
import {Token} from "../../tokenomics/Token.sol";
import {IControllable2} from "../../interfaces/IControllable2.sol";
import {IToken} from "../../interfaces/IToken.sol";
import {console} from "forge-std/console.sol";

library OsDeployLib {
    function deploySeedToken(
        address accessManager,
        string memory token_,
        string memory symbol_
    ) external returns (address) {
        address logic = address(new Token());

        // todo refactoring

        Proxy proxy = new Proxy();
        proxy.initProxy(logic);

        IToken(address(proxy)).initialize(accessManager, token_, symbol_);
        return address(proxy);
    }

    function deployTgeToken(
        address accessManager,
        string memory token_,
        string memory symbol_
    ) external returns (address) {
        address logic = address(new Token());

        // todo refactoring

        Proxy proxy = new Proxy();
        proxy.initProxy(logic);

        IToken(address(proxy)).initialize(accessManager, token_, symbol_);
        return address(proxy);
    }
}
