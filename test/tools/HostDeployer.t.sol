// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HostDeployer} from "../../src/tools/HostDeployer.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IHostAccessManager} from "../../src/interfaces/IHostAccessManager.sol";

contract HostDeployerTest is Test {
    function testDeploy() public {
        HostDeployer deployer = new HostDeployer();
        assertEq(deployer.DEPLOYER(), address(this), "Deployer address");

        bytes32 hostProxyFactorySalt = "0x111";
        bytes32 hostSalt = "0x333";
        address authorityInitialAdmin = makeAddr("multisig");

        (address accessManager, address hostProxyFactory, address host) = deployer.deploy(
            hostProxyFactorySalt,
            hostSalt,
            authorityInitialAdmin,
            abi.encode(IHost.HostInitPayload({usedSymbols: new string[](0), daoHostSymbol: "A", daoHostUid: 999}))
        );

        address expectedHost = deployer.getCreate2Address(hostSalt, deployer.getProxyInitCodeHash(), address(deployer));
        address expectedHostProxyFactory =
            deployer.getCreate2Address(hostProxyFactorySalt, deployer.getProxyInitCodeHash(), address(deployer));

        assertEq(expectedHostProxyFactory, hostProxyFactory, "HostProxyFactory address");

        assertEq(expectedHost, host, "hostSalt address");

        assertEq(IHostAccessManager(accessManager).HOST(), expectedHost, "expected host");

        assertEq(IHosted(hostProxyFactory).authority(), accessManager, "authority of host proxy factory");
        assertEq(IHosted(host).authority(), accessManager, "authority of host");
    }
}
