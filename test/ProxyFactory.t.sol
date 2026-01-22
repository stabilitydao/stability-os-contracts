// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {Host} from "../src/Host.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProxyFactory} from "../src/ProxyFactory.sol";
import {IProxyFactory} from "../src/interfaces/IProxyFactory.sol";
import {Vm, Test} from "forge-std/Test.sol";

contract ProxyFactoryTest is Test {
    function testWhitelist() public {
        ProxyFactory factory = new ProxyFactory();

        assertFalse(factory.whitelisted(address(this)), "by default not whitelisted");

        address logic = address(new Host());

        // ------------------------- createNewProxy can be called without any restrictions
        vm.prank(address(2));
        factory.createNewProxy(logic, "");
        factory.createNewProxy(logic, "");

        // ------------------------- whitelist this and 2
        vm.prank(address(2));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(2)));
        factory.setWhitelisted(address(this), true);

        vm.prank(address(2));
        vm.expectRevert(IProxyFactory.NotWhitelisted.selector);
        factory.create2NewProxy("0x1234", logic, "");

        factory.setWhitelisted(address(this), true);
        factory.setWhitelisted(address(2), true);

        assertTrue(factory.whitelisted(address(this)), "this is whitelisted now");
        assertTrue(factory.whitelisted(address(2)), "2 is whitelisted now");

        // ------------------------- ensure that create2NewProxy works for whitelisted addresses only
        vm.prank(address(2));
        factory.create2NewProxy("0x1234", logic, "");
        factory.create2NewProxy("0x1235", logic, "");

        // ------------------------- un-whitelist this
        vm.prank(address(2));
        vm.expectRevert(); // OwnableUnauthorizedAccount
        factory.setWhitelisted(address(this), false);

        factory.setWhitelisted(address(this), false);

        vm.expectRevert(IProxyFactory.NotWhitelisted.selector);
        factory.create2NewProxy("0x1236", logic, "");

        assertFalse(factory.whitelisted(address(this)), "this is NOT whitelisted now");
    }

    function testProxyFactoryClone() public {
        address logic = address(new Host());

        ProxyFactory factory = new ProxyFactory();
        factory.setWhitelisted(address(this), true);

        address predictedAddress = factory.getCreate2Address("0x1234");
        uint gas = gasleft();
        address deployed = factory.create2NewProxy("0x1234", logic, "");
        uint gasUsed = gas - gasleft();
        assertEq(predictedAddress, deployed, "Deployed address matches predicted");
        console.log("Gas used for clone:", gasUsed);
        assertTrue(gasUsed < 75_000, "gas=68059");
    }

    function testGetCreate2Address() public {
        ProxyFactory factory = new ProxyFactory();

        address predicted1 = factory.getCreate2Address("0x1234");
        address predicted2 = _predictDeterministicAddress(address(factory), "0x1234");
        assertEq(predicted1, predicted2, "getCreate2Address works in the same way as _predictDeterministicAddress");
    }

    function _predictDeterministicAddress(address factory, bytes32 salt) internal view returns (address) {
        return Clones.predictDeterministicAddress(ProxyFactory(factory).MASTER_PROXY(), salt, factory);
    }

    function testEvent() public {
        address logic = address(new Host());

        ProxyFactory factory = new ProxyFactory();
        factory.setWhitelisted(address(this), true);

        address predictedAddress = factory.getCreate2Address("0x1234");

        vm.recordLogs();
        address deployed = factory.create2NewProxy("0x1234", logic, "");
        assertEq(predictedAddress, deployed, "Deployed address matches predicted");

        bytes32 sig = keccak256("ProxyCreated(address)");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        address emitted;
        for (uint i; i < logs.length; ++i) {
            if (logs[i].topics[0] == sig) {
                if (logs[i].topics.length > 1) {
                    emitted = address(uint160(uint(logs[i].topics[1])));
                } else {
                    emitted = abi.decode(logs[i].data, (address));
                }
            }
        }

        assertEq(predictedAddress, emitted, "Emitted address matches deployed one");
    }

    function _keepConsoleInImports() internal pure {
        console.log("we need console in imports");
    }
}
