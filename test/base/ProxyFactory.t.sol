// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {ProxyFactoryCreate} from "../../src/base/ProxyFactoryCreate.sol";
import {ProxyFactory} from "../../src/base/ProxyFactory.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ProxyFactoryTest is Test {
    function testWhitelist() public {
        ProxyFactory factory = new ProxyFactory();

        assertFalse(factory.whitelisted(address(this)), "by default not whitelisted");

        // ------------------------- createNewProxy can be called without any restrictions
        vm.prank(address(2));
        factory.createNewProxy();
        factory.createNewProxy();

        // ------------------------- whitelist this and 2
        vm.prank(address(2));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(2)));
        factory.setWhitelisted(address(this), true);

        vm.prank(address(2));
        vm.expectRevert(ProxyFactory.NotWhitelisted.selector);
        factory.create2NewProxy("0x1234");

        factory.setWhitelisted(address(this), true);
        factory.setWhitelisted(address(2), true);

        assertTrue(factory.whitelisted(address(this)), "this is whitelisted now");
        assertTrue(factory.whitelisted(address(2)),  "2 is whitelisted now");

        // ------------------------- ensure that create2NewProxy works for whitelisted addresses only
        vm.prank(address(2));
        factory.create2NewProxy("0x1234");
        factory.create2NewProxy("0x1235");

        // ------------------------- un-whitelist this
        vm.prank(address(2));
        vm.expectRevert(); // OwnableUnauthorizedAccount
        factory.setWhitelisted(address(this), false);

        factory.setWhitelisted(address(this), false);

        vm.expectRevert(ProxyFactory.NotWhitelisted.selector);
        factory.create2NewProxy("0x1236");

        assertFalse(factory.whitelisted(address(this)), "this is NOT whitelisted now");
    }

    function testProxyFactoryClone() public {
        ProxyFactory factory = new ProxyFactory();
        factory.setWhitelisted(address(this), true);

        bytes32 initCodeHash = factory.getProxyInitCodeHash();
        address predictedAddress = factory.getCreate2Address("0x1234", initCodeHash, address(factory));
        uint gas = gasleft();
        address deployed = factory.create2NewProxy("0x1234");
        uint gasUsed = gas - gasleft();
        assertEq(predictedAddress, deployed, "Deployed address matches predicted");
        assertTrue(gasUsed < 50_000, "gas=42262");
        // console.log("Gas used for clone:", gasUsed);
    }

    /// @notice todo We can remove this test because ProxyFactoryCreate is not used in production
    function testProxyFactoryCreate() public {
        IProxyFactory factory = IProxyFactory(address(new ProxyFactoryCreate()));
        bytes32 initCodeHash = factory.getProxyInitCodeHash();
        address predictedAddress = factory.getCreate2Address("0x1234", initCodeHash, address(factory));
        uint gas = gasleft();
        address deployed = factory.create2NewProxy("0x1234");
        uint gasUsed = gas - gasleft();
        assertEq(predictedAddress, deployed, "Deployed address matches predicted");
        assertTrue(gasUsed > 100_000, "gas=133791");
        // console.log("Gas used for new:", gasUsed);
    }

    function testGetCreate2Address() public {
        ProxyFactory factory = new ProxyFactory();

        bytes32 initCodeHash = factory.getProxyInitCodeHash();
        address predicted1 = factory.getCreate2Address("0x1234", initCodeHash, address(factory));
        address predicted2 = _predictDeterministicAddress(address(factory), "0x1234");
        assertEq(predicted1, predicted2, "getCreate2Address works in the same way as _predictDeterministicAddress");
    }

    function _predictDeterministicAddress(address factory, bytes32 salt) internal view returns (address) {
        return Clones.predictDeterministicAddress(ProxyFactory(factory).MASTER_PROXY(), salt, factory);
    }

}
