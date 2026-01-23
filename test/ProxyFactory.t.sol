// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {console} from "forge-std/console.sol";
import {Host} from "../src/Host.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProxyFactory} from "../src/ProxyFactory.sol";
import {IProxyFactory} from "../src/interfaces/IProxyFactory.sol";
import {IProxy} from "../src/interfaces/IProxy.sol";
import {IHosted} from "../src/interfaces/IHosted.sol";
import {Vm, Test} from "forge-std/Test.sol";
import {MinHostedWithReceive} from "./mocks/MinHostedWithReceive.sol";
import {MinHostedNoReceive} from "./mocks/MinHostedNoReceive.sol";
import {Authority} from "../src/Authority.sol";

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

    function testCreate2NewProxyWhitelisted() public {
        ProxyFactory factory = new ProxyFactory();
        factory.setWhitelisted(address(this), true);

        Authority authority = new Authority(address(this), address(1), address(factory));

        {
            address predictedAddress = factory.predictAddress("0x1234");
            address logic = address(new MinHostedNoReceive());
            uint gas = gasleft();
            address deployed = factory.create2NewProxy("0x1234", logic, "");
            uint gasUsed = gas - gasleft();
            assertEq(predictedAddress, deployed, "Deployed address matches predicted");
            console.log("Gas used for clone:", gasUsed);
            assertTrue(gasUsed < 75_000, "gas=68059");
        }

        {
            address predictedAddress = factory.predictAddress("0x12345");
            address logic = address(new MinHostedNoReceive());
            address deployed =
                factory.create2NewProxy("0x12345", logic, abi.encodeCall(IHosted.initialize, (address(authority), "")));
            assertEq(IProxy(deployed).implementation(), logic, "implementation matches");
            assertEq(IHosted(deployed).authority(), address(authority), "authority matches");
            assertEq(predictedAddress, deployed, "Deployed address matches predicted");
        }

        {
            address logic = address(new MinHostedWithReceive());
            vm.expectRevert(ERC1967Utils.ERC1967NonPayable.selector);
            factory.create2NewProxy{value: 1 ether}("0x123456", logic, "");
        }

        {
            address predictedAddress = factory.predictAddress("0x1234567");
            address logic = address(new MinHostedWithReceive());
            address deployed = factory.create2NewProxy{value: 1 ether}(
                "0x1234567", logic, abi.encodeCall(IHosted.initialize, (address(authority), ""))
            );
            assertEq(deployed.balance, 1 ether, "proxy received 1 ether");
            assertEq(IProxy(deployed).implementation(), logic, "implementation matches");
            assertEq(IHosted(deployed).authority(), address(authority), "authority matches");
            assertEq(predictedAddress, deployed, "Deployed address matches predicted");
        }
    }

    function testCreate2NewProxyNotWhitelisted() public {
        ProxyFactory factory = new ProxyFactory();
        address logic = address(new MinHostedNoReceive());

        vm.expectRevert(IProxyFactory.NotWhitelisted.selector);
        factory.create2NewProxy("0x1234", logic, "");
    }

    function testCreateNewProxyNotWhitelisted() public {
        ProxyFactory factory = new ProxyFactory();

        Authority authority = new Authority(address(this), address(1), address(factory));

        {
            address logic = address(new MinHostedNoReceive());
            address deployed = factory.createNewProxy(logic, "");
            assertEq(IProxy(deployed).implementation(), logic, "implementation matches");
        }

        {
            address logic = address(new MinHostedNoReceive());
            address deployed =
                factory.createNewProxy(logic, abi.encodeCall(IHosted.initialize, (address(authority), "")));
            assertEq(IProxy(deployed).implementation(), logic, "implementation matches");
            assertEq(IHosted(deployed).authority(), address(authority), "authority matches");
        }

        {
            address logic = address(new MinHostedWithReceive());
            vm.expectRevert(ERC1967Utils.ERC1967NonPayable.selector);
            factory.createNewProxy{value: 1 ether}(logic, "");
        }

        {
            address logic = address(new MinHostedWithReceive());
            address deployed = factory.createNewProxy{value: 1 ether}(
                logic, abi.encodeCall(IHosted.initialize, (address(authority), ""))
            );
            assertEq(deployed.balance, 1 ether, "proxy received 1 ether");
            assertEq(IProxy(deployed).implementation(), logic, "implementation matches");
            assertEq(IHosted(deployed).authority(), address(authority), "authority matches");
        }
    }

    function testGetCreate2Address() public {
        ProxyFactory factory = new ProxyFactory();

        address predicted1 = factory.predictAddress("0x1234");
        address predicted2 = _getCreate2Address("0x1234", factory.getProxyInitCodeHash(), address(factory));
        assertEq(predicted1, predicted2, "getCreate2Address works in the same way as predictAddress");
    }

    function testEvent() public {
        address logic = address(new Host());

        ProxyFactory factory = new ProxyFactory();
        factory.setWhitelisted(address(this), true);

        address predictedAddress = factory.predictAddress("0x1234");

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

    function testReceive() public {
        ProxyFactory factory = new ProxyFactory();

        // ----------------- deploy proxy with implementation that has receive()
        {
            uint balanceBefore = address(this).balance;
            address implementation = address(new MinHostedWithReceive());
            address proxy = factory.createNewProxy(implementation, "");
            (bool success,) = proxy.call{value: 1 ether}("");
            assertTrue(success);

            assertEq(proxy.balance, 1 ether, "proxy received ether");
            assertEq(address(this).balance, balanceBefore - 1 ether, "balance decreased");
        }

        // ----------------- deploy proxy with implementation that hasn't receive()
        {
            uint balanceBefore = address(this).balance;
            address implementation = address(new MinHostedNoReceive());
            address proxy = factory.createNewProxy(implementation, "");
            (bool success,) = proxy.call{value: 1 ether}("");
            assertFalse(success);

            assertEq(proxy.balance, 0, "proxy hasn't received ether");
            assertEq(address(this).balance, balanceBefore, "balance unchanged");
        }
    }

    function _keepConsoleInImports() internal pure {
        console.log("we need console in imports");
    }

    function _getCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash,
        address thisAddress
    ) internal pure returns (address) {
        /// @dev The result is same to Clones.predictDeterministicAddress(MASTER_PROXY, salt, address(this)), see tests
        return address(uint160(uint(keccak256(abi.encodePacked(bytes1(0xff), thisAddress, salt, initCodeHash)))));
    }
}
