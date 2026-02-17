// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {AccessRolesLib} from "../../src/libs/AccessRolesLib.sol";
import {HostProxyLib} from "../../src/libs/HostProxyLib.sol";
import {HostUtilsLib} from "../utils/HostUtilsLib.sol";
import {Host} from "../../src/Host.sol";
import {SeedToken} from "../../src/tokenomics/SeedToken.sol";
import {TgeToken} from "../../src/tokenomics/TgeToken.sol";
import {MinHostedNoReceiveV2} from "../mocks/MinHostedNoReceiveV2.sol";
import {MinHostedNoReceive} from "../mocks/MinHostedNoReceive.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IOwnable} from "../../src/interfaces/IOwnable.sol";
import {IUUPSUpgradable} from "../../src/interfaces/IUUPSUpgradable.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {IProxy} from "../../src/interfaces/IProxy.sol";
import {AuthorityAccessUtils} from "../scenario/access/AuthorityAccessUtils.sol";

contract HostProxyLibTest is Test {
    address public multisig;
    address public proxyFactory;
    IAuthority public authority;
    IHost public host;

    constructor() {
        multisig = makeAddr("multisig");

        host = HostUtilsLib.createHostInstance(vm, multisig);
        authority = IAuthority(IHosted(address(host)).authority());
        proxyFactory = authority.PROXY_FACTORY();

        address owner = IOwnable(proxyFactory).owner();

        vm.prank(owner);
        IProxyFactory(proxyFactory).setWhitelisted(address(this), true);

        AuthorityAccessUtils.setRestrictedAccess(
            vm,
            multisig,
            authority,
            address(this),
            AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER,
            address(host),
            IHost.deployProxy.selector
        );
    }

    function testStorageLocation() public pure {
        assertEq(
            keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostProxyLib")) - 1))
                & ~bytes32(uint(0xff)),
            HostProxyLib.HOST_UPGRADE_STORAGE_LOCATION,
            "HOST_UPGRADE_STORAGE_LOCATION"
        );
    }

    //region ------------------------------------- Deploy tests
    function testSetContractImplementation() public {
        address seedTokenImplementation = address(new SeedToken());
        address tgeTokenImplementation = address(new TgeToken());

        vm.expectRevert(); // AccessManagedUnauthorized
        vm.prank(address(1111));
        host.setContractImplementation(uint(ITokenomics.ContractIndices.SEED_TOKEN_1), seedTokenImplementation);

        vm.prank(multisig);
        host.setContractImplementation(uint(ITokenomics.ContractIndices.SEED_TOKEN_1), seedTokenImplementation);

        vm.prank(multisig);
        host.setContractImplementation(uint(ITokenomics.ContractIndices.TGE_TOKEN_2), tgeTokenImplementation);

        assertEq(
            host.contractImplementation(uint(ITokenomics.ContractIndices.SEED_TOKEN_1)),
            seedTokenImplementation,
            "Seed token implementation set"
        );
        assertEq(
            host.contractImplementation(uint(ITokenomics.ContractIndices.TGE_TOKEN_2)),
            tgeTokenImplementation,
            "Tge token implementation set"
        );

        vm.prank(multisig);
        host.setContractImplementation(uint(ITokenomics.ContractIndices.TGE_TOKEN_2), address(0));

        assertEq(
            host.contractImplementation(uint(ITokenomics.ContractIndices.SEED_TOKEN_1)),
            seedTokenImplementation,
            "Seed token implementation not changed"
        );
        assertEq(
            host.contractImplementation(uint(ITokenomics.ContractIndices.TGE_TOKEN_2)),
            address(0),
            "Tge token implementation is zero"
        );
    }

    function testDeploySeedToken() public {
        // ------------------------ Setup implementations
        address seedTokenImplementation = address(new SeedToken());

        HostProxyLib.setContractImplementation(uint(ITokenomics.ContractIndices.SEED_TOKEN_1), seedTokenImplementation);

        // ------------------------ Deploy seed token

        bytes32 salt = "0x0101";
        address predictedProxyAddress = IProxyFactory(proxyFactory).predictAddress(salt);

        uint daoUid = 1000;
        address seedToken = HostProxyLib.deployContract(
            salt, uint(IHost.ContractKinds.SEED_TOKEN_1), abi.encode(daoUid), address(authority)
        );

        // ------------------------ Check results
        assertNotEq(seedToken, address(0), "Deployed seed token address");
        assertEq(seedToken, predictedProxyAddress, "Predicted address matches deployed");

        assertEq(IERC20Metadata(seedToken).name(), " SEED", "Seed token name (dao name is empty here)");
        assertEq(IERC20Metadata(seedToken).symbol(), "seed", "Seed token symbol (dao name is empty here)");

        assertEq(IProxy(seedToken).implementation(), seedTokenImplementation, "Seed token implementation");
    }

    function testDeployTgeToken() public {
        // ------------------------ Setup implementations
        address tgeTokenImplementation = address(new TgeToken());

        HostProxyLib.setContractImplementation(uint(ITokenomics.ContractIndices.TGE_TOKEN_2), tgeTokenImplementation);

        // ------------------------ Deploy seed token

        uint daoUid = 1000;
        bytes32 salt = "0x0101";
        address predictedProxyAddress = IProxyFactory(proxyFactory).predictAddress(salt);

        address tgeToken = HostProxyLib.deployContract(
            salt, uint(IHost.ContractKinds.TGE_TOKEN_2), abi.encode(daoUid), address(authority)
        );

        // ------------------------ Check results
        assertNotEq(tgeToken, address(0), "Deployed tge token address");
        assertEq(tgeToken, predictedProxyAddress, "Predicted address matches deployed");

        assertEq(IERC20Metadata(tgeToken).name(), " PRESALE", "Tge token name (dao name is empty here)");
        assertEq(IERC20Metadata(tgeToken).symbol(), "sale", "Tge token symbol (dao name is empty here)");

        assertEq(IProxy(tgeToken).implementation(), tgeTokenImplementation, "Tge token implementation");
    }

    function testDeployProxy() public {
        address logic = address(new Host());

        bytes32 salt = "0x0101";
        address predictedProxyAddress = IProxyFactory(proxyFactory).predictAddress(salt);

        string[] memory usedSymbols = new string[](2);
        usedSymbols[0] = "AAA";
        usedSymbols[1] = "BBB";

        IHost.HostInitPayload memory init = IHost.HostInitPayload({
            usedSymbols: usedSymbols, daoHostSymbol: "CCC", daoHostUid: 12345, hostVersion: "1.0.0"
        });

        vm.expectRevert();
        vm.prank(address(2222));
        IHost(host.deployProxy(salt, address(logic), abi.encode(init)));

        IHost newHost = IHost(host.deployProxy(salt, address(logic), abi.encode(init)));

        assertTrue(newHost.isDaoSymbolInUse("AAA"), "AAA");
        assertTrue(newHost.isDaoSymbolInUse("BBB"), "BBB");

        assertTrue(newHost.isDaoSymbolInUse("CCC"), "CCC");
        assertEq(newHost.hostDaoUid(), 12345, "CCC uid");

        assertEq(address(newHost), predictedProxyAddress, "Predicted address matches deployed");
    }

    //endregion ------------------------------------- Deploy tests

    //region ------------------------------------- Upgrade tests
    function testUpgradeHost() public {
        // ------------------------- Deploy two proxies
        vm.startPrank(multisig);
        address[] memory proxies = new address[](2);
        proxies[0] = host.deployProxy("0x1", address(new MinHostedNoReceive()), "");
        proxies[1] = host.deployProxy("0x2", address(new MinHostedNoReceiveV2()), "");
        vm.stopPrank();

        // ------------------------- Allow host to upgrade proxies
        _setupContractUpgrader(authority, proxies[0], address(host));
        _setupContractUpgrader(authority, proxies[1], address(host));

        // ------------------------- Create new implementations
        address[] memory implementations = new address[](2);
        implementations[0] = address(new MinHostedNoReceiveV2()); // upgrade
        implementations[1] = address(new MinHostedNoReceive()); // downgrade

        // ------------------------- Announce upgrade
        vm.prank(multisig);
        host.announceUpgrade("1.1.0", proxies, implementations);

        {
            (string memory newVersion, address[] memory newProxies, address[] memory newImplementations) =
                host.pendingUpgrade();
            assertEq(keccak256(bytes(newVersion)), keccak256(bytes("1.1.0")), "new version announced");
            assertEq(
                keccak256(abi.encode(newImplementations)),
                keccak256(abi.encode(implementations)),
                "implementations announced"
            );
            assertEq(keccak256(abi.encode(newProxies)), keccak256(abi.encode(proxies)), "proxies announced");
        }

        // ------------------------- Wait timelock
        vm.warp(block.timestamp + 31 minutes);

        // ------------------------- Check functions before upgrade
        vm.expectRevert();
        MinHostedNoReceiveV2(proxies[0]).newFunction();
        MinHostedNoReceiveV2(proxies[1]).newFunction();

        assertEq(MinHostedNoReceive(proxies[0]).testFunction(), 1, "before 1");
        assertEq(MinHostedNoReceiveV2(proxies[1]).testFunction(), 1, "before 2");

        // ------------------------- Upgrade and check functions after upgrade
        vm.prank(multisig);
        host.upgrade();

        {
            (string memory newVersion, address[] memory newProxies, address[] memory newImplementations) =
                host.pendingUpgrade();
            assertEq(keccak256(bytes(newVersion)), keccak256(bytes("")), "no new version announced");
            assertEq(keccak256(abi.encode(newProxies)), keccak256(abi.encode(new address[](0))), "no proxies announced");
            assertEq(
                keccak256(abi.encode(newImplementations)),
                keccak256(abi.encode(new address[](0))),
                "no implementations announced"
            );
        }

        MinHostedNoReceiveV2(proxies[0]).newFunction();
        vm.expectRevert();
        MinHostedNoReceiveV2(proxies[1]).newFunction();

        assertEq(MinHostedNoReceiveV2(proxies[0]).testFunction(), 1, "after 1");
        assertEq(MinHostedNoReceive(proxies[1]).testFunction(), 1, "after 2");

        assertEq(keccak256(bytes(IHosted(proxies[0]).VERSION())), keccak256(bytes("2.0.0")), "version 2 after upgrade ");
        assertEq(keccak256(bytes(IHosted(proxies[1]).VERSION())), keccak256(bytes("1.0.0")), "version 1 after upgrade ");

        assertEq(host.hostVersion(), "1.1.0", "host version is updated");
    }

    function testUpgradeHostBadPaths() public {
        // ------------------------- Deploy two proxies
        vm.startPrank(multisig);
        address[] memory proxies = new address[](2);
        proxies[0] = host.deployProxy("0x1", address(new MinHostedNoReceive()), "");
        proxies[1] = host.deployProxy("0x2", address(new MinHostedNoReceiveV2()), "");
        vm.stopPrank();

        // ------------------------- Allow host to upgrade proxies
        _setupContractUpgrader(authority, proxies[0], address(host));
        _setupContractUpgrader(authority, proxies[1], address(host));

        // ------------------------- Create new implementations
        address[] memory implementations = new address[](2);
        implementations[0] = address(new MinHostedNoReceiveV2()); // upgrade
        implementations[1] = address(new MinHostedNoReceive()); // downgrade

        // ------------------------- Bad paths
        {
            address[] memory implementations2 = new address[](1);
            implementations2[0] = address(new MinHostedNoReceiveV2()); // upgrade

            vm.expectRevert(IHost.IncorrectArrayLengths.selector);
            vm.prank(multisig);
            host.announceUpgrade("1.1.0", proxies, implementations2);

            implementations2 = new address[](implementations.length);
            for (uint i = 0; i < implementations.length - 1; i++) {
                implementations2[i] = i == 0 ? address(0) : implementations[i];
            }

            vm.expectRevert(IHosted.IncorrectZeroArgument.selector);
            vm.prank(multisig);
            host.announceUpgrade("1.1.0", proxies, implementations2);

            vm.expectRevert(IHosted.IncorrectZeroArgument.selector);
            vm.prank(multisig);
            host.announceUpgrade("1.1.0", implementations2, proxies);

            implementations2 = new address[](2);
            implementations2[0] = address(new MinHostedNoReceive()); // upgrade
            implementations2[1] = address(new MinHostedNoReceiveV2()); // downgrade

            vm.expectRevert(IHost.SameVersion.selector);
            vm.prank(multisig);
            host.announceUpgrade("1.1.0", implementations2, proxies);

            vm.expectRevert(IHost.SameVersion.selector);
            vm.prank(multisig);
            host.announceUpgrade("1.0.0", implementations, proxies);

            vm.expectRevert(); // restricted
            vm.prank(address(0x1111));
            host.announceUpgrade("1.1.0", proxies, implementations);
        }

        // ------------------------- Announce upgrade
        vm.prank(multisig);
        host.announceUpgrade("1.1.0", proxies, implementations);

        // ------------------------- Bad paths
        {
            // We cannot announce next upgrade before executing or cancelling the previous one
            vm.expectRevert(IHost.AlreadyAnnounced.selector);
            vm.prank(multisig);
            host.announceUpgrade("1.2.0", proxies, implementations);

            // We cannot upgrade before timelock
            vm.expectRevert(abi.encodeWithSelector(IHost.UpgradeTimerIsNotOver.selector, uint(1801)));
            vm.prank(multisig);
            host.upgrade();
        }

        // ------------------------- Wait timelock
        vm.warp(block.timestamp + 31 minutes);

        // ------------------------- Upgrade and check functions after upgrade
        vm.expectRevert(); // restricted
        vm.prank(address(0x1));
        host.upgrade();

        vm.prank(multisig);
        host.upgrade();

        // ------------------------- Bad paths
        {
            // nothing to cancel
            vm.expectRevert(IHost.NoNewVersion.selector);
            vm.prank(multisig);
            host.cancelUpgrade();
        }
    }

    function testCancelUpgradeHost() public {
        // ------------------------- Deploy two proxies
        vm.startPrank(multisig);
        address[] memory proxies = new address[](2);
        proxies[0] = host.deployProxy("0x1", address(new MinHostedNoReceive()), "");
        proxies[1] = host.deployProxy("0x2", address(new MinHostedNoReceiveV2()), "");
        vm.stopPrank();

        // ------------------------- Allow host to upgrade proxies
        _setupContractUpgrader(authority, proxies[0], address(host));
        _setupContractUpgrader(authority, proxies[1], address(host));

        // ------------------------- Create new implementations
        address[] memory implementations = new address[](2);
        implementations[0] = address(new MinHostedNoReceiveV2()); // upgrade
        implementations[1] = address(new MinHostedNoReceive()); // downgrade

        // ------------------------- Announce upgrade
        vm.prank(multisig);
        host.announceUpgrade("1.1.0", proxies, implementations);

        console.log("Host version before upgrade:", host.hostVersion());

        assertEq(keccak256(bytes(host.hostVersion())), keccak256(bytes("1.0.0")), "initial host version");

        assertEq(keccak256(bytes(IHosted(proxies[0]).VERSION())), keccak256(bytes("1.0.0")), "version not changed");
        assertEq(keccak256(bytes(IHosted(proxies[1]).VERSION())), keccak256(bytes("2.0.0")), "version not changed");

        // ------------------------- Cancel upgrade at any time
        vm.prank(multisig);
        host.cancelUpgrade();

        assertEq(keccak256(bytes(IHosted(proxies[0]).VERSION())), keccak256(bytes("1.0.0")), "version not changed");
        assertEq(keccak256(bytes(IHosted(proxies[1]).VERSION())), keccak256(bytes("2.0.0")), "version not changed");

        assertEq(keccak256(bytes(host.hostVersion())), keccak256(bytes("1.0.0")), "host version is NOT updated");

        // ------------------------- Ensure that pending update is cleared
        {
            (string memory newVersion, address[] memory newProxies, address[] memory newImplementations) =
                host.pendingUpgrade();
            assertEq(keccak256(bytes(newVersion)), keccak256(bytes("")), "no new version announced");
            assertEq(keccak256(abi.encode(newProxies)), keccak256(abi.encode(new address[](0))), "no proxies announced");
            assertEq(
                keccak256(abi.encode(newImplementations)),
                keccak256(abi.encode(new address[](0))),
                "no implementations announced"
            );
        }
    }

    //endregion ------------------------------------- Upgrade tests

    //region ------------------------------------- Internal utils
    function _setupAccessManager(IAuthority authority_, address host_) internal {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = bytes4(IHost.upgrade.selector);
        selectors[1] = bytes4(IHost.announceUpgrade.selector);
        selectors[2] = bytes4(IHost.cancelUpgrade.selector);
        selectors[3] = bytes4(IHost.deployProxy.selector);

        vm.prank(multisig);
        authority_.setTargetFunctionRole(host_, selectors, AccessRolesLib.HOST_UPGRADER);

        vm.prank(multisig);
        authority_.grantRole(AccessRolesLib.HOST_UPGRADER, multisig, 0);

        vm.prank(multisig);
        authority_.grantRole(AccessRolesLib.HOST_UPGRADER, address(this), 0);
    }

    function _setupContractUpgrader(IAuthority authority_, address proxy, address upgrader) internal {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(IUUPSUpgradable.upgradeToAndCall.selector);

        vm.prank(multisig);
        authority_.setTargetFunctionRole(proxy, selectors, AccessRolesLib.CONTRACTS_UPGRADER);

        vm.prank(multisig);
        authority_.grantRole(AccessRolesLib.CONTRACTS_UPGRADER, upgrader, 0);
    }
    //endregion ------------------------------------- Internal utils
}
