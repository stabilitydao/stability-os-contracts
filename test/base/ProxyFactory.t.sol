// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {ProxyFactoryNew} from "../../src/base/ProxyFactoryNew.sol";
import {ProxyFactory} from "../../src/base/ProxyFactory.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract ProxyFactoryTest is Test {

    function testProxyFactoryNew() public {
        IProxyFactory factory = IProxyFactory(address(new ProxyFactoryNew()));
        bytes32 initCodeHash = factory.getProxyInitCodeHash();
        address predictedAddress = factory.getCreate2Address("0x1234", initCodeHash, address(factory));
        uint gas = gasleft();
        address deployed = factory.create2NewProxy("0x1234");
        uint gasUsed = gas - gasleft();
        assertEq(predictedAddress, deployed, "Deployed address matches predicted");
        console.log("Gas used for create2NewProxy:", gasUsed);
    }

    function testProxyFactoryClone() public {
        IProxyFactory factory = IProxyFactory(address(new ProxyFactory()));
        bytes32 initCodeHash = factory.getProxyInitCodeHash();
        address predictedAddress = factory.getCreate2Address("0x1234", initCodeHash, address(factory));
        uint gas = gasleft();
        address deployed = factory.create2NewProxy("0x1234");
        uint gasUsed = gas - gasleft();
        assertEq(predictedAddress, deployed, "Deployed address matches predicted");
        console.log("Gas used for create2NewProxy:", gasUsed);

        address predicted = _predictDeterministicAddress(address(factory), "0x1234");
        assertEq(predicted, deployed, "Predicted address matches deployed");
    }

    function _predictDeterministicAddress(address factory, bytes32 salt) internal view returns (address) {
        return Clones.predictDeterministicAddress(ProxyFactory(factory).MASTER_PROXY(), salt, factory);
    }

}
