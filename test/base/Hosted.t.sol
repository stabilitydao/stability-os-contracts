// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {Authority} from "../../src/Authority.sol";
import {Host} from "../../src/Host.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IAuthority} from "../../lib/openzeppelin-contracts/contracts/access/manager/IAuthority.sol";
import {IERC1822Proxiable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IOldControllable {
    function platform() external view returns (address);
}

contract HostedTest is Test {
    address internal constant MULTISIG = address(0xFFFFFFFF);
    address internal constant UPGRADER = address(0xAAAAAAA1);

    ProxyFactory internal proxyFactory;
    Authority internal authority;
    IHost.HostInitPayload internal emptyHostPayload;
    IHost.HostInitPayload internal notEmptyHostPayload;
    address internal logic;

    constructor() {
        emptyHostPayload = IHost.HostInitPayload({
            usedSymbols: new string[](0),
            hostVersion: "1.0.0",
            daoHost: IHost.DaoHostInitParams({uid: 0, symbol: "", name: "", unitIds: new string[](0)})
        });
        {
            string[] memory usedSymbols = new string[](1);
            usedSymbols[0] = "B";

            notEmptyHostPayload = IHost.HostInitPayload({
                usedSymbols: usedSymbols,
                hostVersion: "1.0.0",
                daoHost: IHost.DaoHostInitParams({uid: 1, symbol: "A", name: "", unitIds: new string[](0)})
            });
        }

        logic = address(new Host());

        // ------------------- deploy proxy factory
        vm.prank(MULTISIG);
        proxyFactory = new ProxyFactory();

        // ------------------- deploy authority
        address hostPredicted = proxyFactory.predictAddress("0x62436");
        authority = new Authority(MULTISIG, hostPredicted, address(proxyFactory));

        vm.prank(MULTISIG);
        proxyFactory.setWhitelisted(address(authority), true);

        vm.prank(MULTISIG);
        proxyFactory.setWhitelisted(hostPredicted, true);
    }

    function testInitWithZeroAuthority() public {
        vm.expectRevert(IHosted.IncorrectZeroArgument.selector);
        vm.prank(MULTISIG);
        authority.execute(
            address(proxyFactory),
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                ("0x62436", logic, abi.encodeCall(IHosted.initialize, (address(0), abi.encode(emptyHostPayload))))
            )
        );
    }

    function testSupportsInterface() public {
        ProxyFactory factory = new ProxyFactory();
        factory.setWhitelisted(address(this), true);

        address proxy = factory.create2NewProxy("0x1234", logic, "");

        assertTrue(IERC165(proxy).supportsInterface(type(IHosted).interfaceId), "IHosted supported");
        assertTrue(IERC165(proxy).supportsInterface(type(IAccessManaged).interfaceId), "IAccessManaged supported");
        assertTrue(IERC165(proxy).supportsInterface(type(IERC1822Proxiable).interfaceId), "IERC1822Proxiable supported");
        assertFalse(IERC165(proxy).supportsInterface(type(IAuthority).interfaceId), "IAuthority supported");
    }

    function testPlatform() public {
        ProxyFactory factory = new ProxyFactory();
        factory.setWhitelisted(address(this), true);

        address proxy = factory.create2NewProxy("0x1234", logic, "");

        vm.expectRevert("platform is deprecated");
        IOldControllable(proxy).platform();
    }

    function testCreateBlock() public {
        ProxyFactory factory = new ProxyFactory();
        factory.setWhitelisted(address(this), true);

        uint startBlock = block.number;

        address proxy = factory.create2NewProxy(
            "0x1234", logic, abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(emptyHostPayload)))
        );

        uint createdBlock = IHosted(proxy).createdBlock();
        assertEq(createdBlock, startBlock, "created block is correct");
    }
}

