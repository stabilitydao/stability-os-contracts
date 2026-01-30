// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {ProxyFactory} from "../src/ProxyFactory.sol";
import {Authority} from "../src/Authority.sol";
import {Host} from "../src/Host.sol";
import {IProxyFactory} from "../src/interfaces/IProxyFactory.sol";
import {IHost} from "../src/interfaces/IHost.sol";
import {IHosted} from "../src/interfaces/IHosted.sol";
import {Test} from "forge-std/Test.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {console} from "forge-std/console.sol";

contract AuthorityTest is Test {
    address internal constant MULTISIG = address(0xFFFFFFFF);

    function testDeployHost() public {
        string[] memory usedSymbols = new string[](1);
        usedSymbols[0] = "B";

        IHost.HostInitPayload memory hostPayload =
            IHost.HostInitPayload({usedSymbols: usedSymbols, daoHostSymbol: "A", daoHostUid: 1, hostVersion: "1.0.0"});

        // ------------------- deploy proxy factory
        vm.prank(MULTISIG);
        ProxyFactory proxyFactory = new ProxyFactory();

        // ------------------- deploy authority
        address hostPredicted = proxyFactory.predictAddress("0x62436");
        Authority authority = new Authority(MULTISIG, hostPredicted, address(proxyFactory));

        vm.prank(MULTISIG);
        proxyFactory.setWhitelisted(address(authority), true);

        vm.prank(MULTISIG);
        proxyFactory.setWhitelisted(hostPredicted, true);

        // ------------------- prepare to create host - set up the calls
        address logic = address(new Host());

        bytes[] memory calls = new bytes[](2);

        // 1. create2NewProxy
        calls[0] = abi.encodeCall(
            AccessManager.execute,
            (address(proxyFactory), abi.encodeCall(IProxyFactory.create2NewProxy, ("0x62436", logic, "")))
        );

        // 2. initialize host
        calls[1] = abi.encodeCall(
            AccessManager.execute,
            (hostPredicted, abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(hostPayload))))
        );

        // ------------------- create host via multicall
        vm.expectRevert(); // AccessManagerUnauthorizedCall - only admin can call
        vm.prank(address(this));
        authority.multicall(calls);

        vm.prank(MULTISIG);
        authority.multicall(calls);

        // ------------------- verify host
        IHost host = IHost(hostPredicted);
        assertEq(IAccessManaged(hostPredicted).authority(), address(authority), "host authority");
        assertNotEq(host.getHostDaoUid(), 0, "host dao uid set");
        assertEq(host.getHostDaoUid(), host.getDAO("A").uid, "host dao uid");
        assertEq(host.isDaoSymbolInUse("B"), true, "host used symbol");
        assertEq(keccak256(bytes(host.hostVersion())), keccak256(bytes("1.0.0")), "host version");

        // -------------------- verify authority
        assertEq(authority.HOST(), hostPredicted, "authority host");
        assertEq(authority.PROXY_FACTORY(), address(proxyFactory), "authority proxy factory");
    }

    function testDeployAuthorityGasEstimation() public {
        IHost.HostInitPayload memory hostPayload = IHost.HostInitPayload({
            usedSymbols: new string[](0), daoHostSymbol: "", daoHostUid: 0, hostVersion: "1.0.0"
        });

        // ------------------- deploy proxy factory
        uint gas = gasleft();
        vm.prank(MULTISIG);
        ProxyFactory proxyFactory = new ProxyFactory();
        console.log("Gas used for ProxyFactory deployment:", gas - gasleft());

        // ------------------- deploy authority
        address hostPredicted = proxyFactory.predictAddress("0x62436");
        gas = gasleft();
        Authority authority = new Authority(MULTISIG, hostPredicted, address(proxyFactory));
        console.log("Gas used for Authority deployment:", gas - gasleft());

        vm.prank(MULTISIG);
        proxyFactory.setWhitelisted(address(authority), true);

        vm.prank(MULTISIG);
        proxyFactory.setWhitelisted(hostPredicted, true);

        // ------------------- prepare to create host - set up the calls
        gas = gasleft();
        address logic = address(new Host());

        vm.prank(MULTISIG);
        authority.execute(
            address(proxyFactory),
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                ("0x62436", logic, abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(hostPayload))))
            )
        );
        console.log("Gas used for Host deployment:", gas - gasleft());
    }
}
