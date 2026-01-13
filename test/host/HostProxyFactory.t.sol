// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../src/tokenomics/TgeToken.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {AccessRolesLib} from "../../src/core/libs/AccessRolesLib.sol";
import {HostProxyFactory} from "../../src/host/HostProxyFactory.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IControllable2} from "../../src/interfaces/IControllable2.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IHostProxyFactory} from "../../src/interfaces/IHostProxyFactory.sol";
import {IProxy} from "../../src/interfaces/IProxy.sol";
import {Proxy} from "../../src/core/proxy/Proxy.sol";
import {SeedToken} from "../../src/tokenomics/SeedToken.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract HostProxyFactoryTest is Test {
    IAccessManager internal accessManager;
    address internal multisig;
    HostProxyFactory internal factory;

    constructor() {
        multisig = makeAddr("multisig");
        accessManager = new AccessManager(multisig);

        address proxy = address(new Proxy());
        IProxy(proxy).initProxy(address(new HostProxyFactory()));
        IControllable2(proxy).initialize(address(accessManager), "");
        factory = HostProxyFactory(proxy);

        setupAccessManager();
    }

    function testStorageLocation() internal pure {
        console.log("keccak256(abi.encode(uint(keccak256(erc7201:stability-os-contracts.HostProxyFactory))))");
        console.logBytes32(
            keccak256(abi.encode(uint(keccak256("erc7201:stability-os-contracts.HostProxyFactory")) - 1))
                & ~bytes32(uint(0xff))
        );
    }

    function testSeedTokenImplementationRestricted() public {
        address seedTokenImplementation = address(new SeedToken());

        vm.expectRevert(); // AccessManagedUnauthorized
        vm.prank(address(1111));
        factory.setSeedTokenImplementation(seedTokenImplementation);

        vm.prank(multisig);
        factory.setSeedTokenImplementation(seedTokenImplementation);

        assertEq(factory.seedTokenImplementation(), seedTokenImplementation, "Seed token implementation set");
    }

    function testTgeTokenImplementationRestricted() public {
        address tgeTokenImplementation = address(new TgeToken());

        vm.expectRevert(); // AccessManagedUnauthorized
        vm.prank(address(1111));
        factory.setTgeTokenImplementation(tgeTokenImplementation);

        vm.prank(multisig);
        factory.setTgeTokenImplementation(tgeTokenImplementation);

        assertEq(factory.tgeTokenImplementation(), tgeTokenImplementation, "Tge token implementation set");
    }

    function testDeploySeedToken() public {
        // ------------------------ Setup implementations
        address seedTokenImplementation = address(new SeedToken());

        vm.prank(multisig);
        factory.setSeedTokenImplementation(seedTokenImplementation);

        // ------------------------ Deploy seed token
        bytes32 salt = "0x0101";
        bytes32 proxyInitCodeHash = factory.getProxyInitCodeHash();
        address predictedProxyAddress = factory.getCreate2Address(salt, proxyInitCodeHash, address(factory));

        vm.expectRevert();
        vm.prank(address(2222));
        factory.deploySeedToken(salt, abi.encode("name", "symbol"));

        vm.prank(address(this));
        address seedToken = factory.deploySeedToken(salt, abi.encode("name", "symbol"));

        // ------------------------ Check results
        assertNotEq(seedToken, address(0), "Deployed seed token address");
        assertEq(seedToken, predictedProxyAddress, "Predicted address matches deployed");

        assertEq(factory.seedTokens().length, 1, "Seed tokens length");
        assertEq(factory.seedTokens()[0], seedToken, "Expected seed token in factory list");

        assertEq(IERC20Metadata(seedToken).name(), "name", "Seed token name");
        assertEq(IERC20Metadata(seedToken).symbol(), "symbol", "Seed token symbol");
    }

    function testDeployTgeToken() public {
        // ------------------------ Setup implementations
        address tgeTokenImplementation = address(new TgeToken());

        vm.prank(multisig);
        factory.setTgeTokenImplementation(tgeTokenImplementation);

        // ------------------------ Deploy seed token
        bytes32 salt = "0x0101";
        bytes32 proxyInitCodeHash = factory.getProxyInitCodeHash();
        address predictedProxyAddress = factory.getCreate2Address(salt, proxyInitCodeHash, address(factory));

        vm.expectRevert();
        vm.prank(address(2222));
        factory.deployTgeToken(salt, abi.encode("name", "symbol"));

        vm.prank(address(this));
        address tgeToken = factory.deployTgeToken(salt, abi.encode("name", "symbol"));

        // ------------------------ Check results
        assertNotEq(tgeToken, address(0), "Deployed tge token address");
        assertEq(tgeToken, predictedProxyAddress, "Predicted address matches deployed");

        assertEq(factory.tgeTokens().length, 1, "Tge tokens length");
        assertEq(factory.tgeTokens()[0], tgeToken, "Expected tge token in factory list");

        assertEq(IERC20Metadata(tgeToken).name(), "name", "Tge token name");
        assertEq(IERC20Metadata(tgeToken).symbol(), "symbol", "Tge token symbol");
    }

    function setupAccessManager() internal {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(IHostProxyFactory.setSeedTokenImplementation.selector);
        selectors[1] = bytes4(IHostProxyFactory.setTgeTokenImplementation.selector);

        vm.prank(multisig);
        accessManager.setTargetFunctionRole(address(factory), selectors, AccessRolesLib.HOST_PROXY_FACTORY_ADMIN);

        selectors = new bytes4[](2);
        selectors[0] = bytes4(IHostProxyFactory.deploySeedToken.selector);
        selectors[1] = bytes4(IHostProxyFactory.deployTgeToken.selector);

        vm.prank(multisig);
        accessManager.setTargetFunctionRole(address(factory), selectors, AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER);

        vm.prank(multisig);
        accessManager.grantRole(AccessRolesLib.HOST_PROXY_FACTORY_ADMIN, multisig, 0);

        vm.prank(multisig);
        accessManager.grantRole(AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER, address(this), 0);
    }
}
