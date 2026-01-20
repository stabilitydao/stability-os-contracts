// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {ProxyFactory} from "../../src/base/ProxyFactory.sol";
import {ProxyFactory2} from "../../src/base/ProxyFactory2.sol";

contract ProxyFactoryTest is Test {

    function testCreate2NewProxy() public {
        IProxyFactory factory = IProxyFactory(address(new ProxyFactory()));
        bytes32 initCodeHash = factory.getProxyInitCodeHash();
        address predictedAddress = factory.getCreate2Address("0x1234", initCodeHash, address(factory));
        uint gas = gasleft();
        address deployed = factory.create2NewProxy("0x1234");
        uint gasUsed = gas - gasleft();
        assertEq(predictedAddress, deployed, "Deployed address matches predicted");
        console.log("Gas used for create2NewProxy:", gasUsed);
    }

    function testCreate2NewProxy2() public {
        IProxyFactory factory = IProxyFactory(address(new ProxyFactory2()));
        bytes32 initCodeHash = factory.getProxyInitCodeHash();
        address predictedAddress = factory.getCreate2Address("0x1234", initCodeHash, address(factory));
        uint gas = gasleft();
        address deployed = factory.create2NewProxy("0x1234");
        uint gasUsed = gas - gasleft();
        assertEq(predictedAddress, deployed, "Deployed address matches predicted");
        console.log("Gas used for create2NewProxy:", gasUsed);

        address predicted = ProxyFactory2(address(factory)).predictDeterministicAddress("0x1234");
        assertEq(predicted, deployed, "Predicted address matches deployed");
    }
}
