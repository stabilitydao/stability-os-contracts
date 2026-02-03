// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Host} from "../../src/Host.sol";
import {AccessRolesLib} from "../../src/libs/AccessRolesLib.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {IProxy} from "../../src/interfaces/IProxy.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {SeedToken} from "../../src/tokenomics/SeedToken.sol";
import {TgeToken} from "../../src/tokenomics/TgeToken.sol";
import {HostUtilsLib} from "../utils/HostUtilsLib.sol";
import {HostProxyFactoryLib} from "../../src/libs/HostProxyFactoryLib.sol";
import {IOwnable} from "../../src/deprecated/interfaces/IOwnable.sol";

contract HostProxyFactoryLibTest is Test {
    address internal multisig;
    address internal proxyFactory;
    IAuthority internal authority;
    IHost internal host;

    constructor() {
        multisig = makeAddr("multisig");
        host = HostUtilsLib.createHostInstance(vm, multisig);
        authority = IAuthority(IHosted(address(host)).authority());
        proxyFactory = authority.PROXY_FACTORY();

        address owner = IOwnable(proxyFactory).owner();

        vm.prank(owner);
        IProxyFactory(proxyFactory).setWhitelisted(address(this), true);

        _setupAccessManager();
    }

    function testStorageLocation() internal pure {
        console.log("keccak256(abi.encode(uint(keccak256(erc7201:stability.host-contracts.HostProxyFactoryLib))))");
        console.logBytes32(
            keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.HostProxyFactoryLib")) - 1))
                & ~bytes32(uint(0xff))
        );
    }

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

        HostProxyFactoryLib.setContractImplementation(
            uint(ITokenomics.ContractIndices.SEED_TOKEN_1), seedTokenImplementation
        );

        // ------------------------ Deploy seed token

        bytes32 salt = "0x0101";
        address predictedProxyAddress = IProxyFactory(proxyFactory).predictAddress(salt);

        address seedToken = HostProxyFactoryLib.deployContract(
            salt, uint(IHost.ContractKinds.SEED_TOKEN_1), abi.encode("name", "symbol"), address(authority)
        );

        // ------------------------ Check results
        assertNotEq(seedToken, address(0), "Deployed seed token address");
        assertEq(seedToken, predictedProxyAddress, "Predicted address matches deployed");

        assertEq(IERC20Metadata(seedToken).name(), "name", "Seed token name");
        assertEq(IERC20Metadata(seedToken).symbol(), "symbol", "Seed token symbol");

        assertEq(IProxy(seedToken).implementation(), seedTokenImplementation, "Seed token implementation");
    }

    function testDeployTgeToken() public {
        // ------------------------ Setup implementations
        address tgeTokenImplementation = address(new TgeToken());

        HostProxyFactoryLib.setContractImplementation(
            uint(ITokenomics.ContractIndices.TGE_TOKEN_2), tgeTokenImplementation
        );

        // ------------------------ Deploy seed token

        bytes32 salt = "0x0101";
        address predictedProxyAddress = IProxyFactory(proxyFactory).predictAddress(salt);

        address tgeToken = HostProxyFactoryLib.deployContract(
            salt, uint(IHost.ContractKinds.TGE_TOKEN_2), abi.encode("name", "symbol"), address(authority)
        );

        // ------------------------ Check results
        assertNotEq(tgeToken, address(0), "Deployed tge token address");
        assertEq(tgeToken, predictedProxyAddress, "Predicted address matches deployed");

        assertEq(IERC20Metadata(tgeToken).name(), "name", "Tge token name");
        assertEq(IERC20Metadata(tgeToken).symbol(), "symbol", "Tge token symbol");

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
        assertEq(newHost.getHostDaoUid(), 12345, "CCC uid");

        assertEq(address(newHost), predictedProxyAddress, "Predicted address matches deployed");
    }

    function _setupAccessManager() internal {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(IHost.deployProxy.selector);

        vm.prank(multisig);
        IAccessManager(address(authority))
            .setTargetFunctionRole(address(host), selectors, AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER);

        vm.prank(multisig);
        IAccessManager(address(authority)).grantRole(AccessRolesLib.HOST_PROXY_FACTORY_ADMIN, multisig, 0);

        vm.prank(multisig);
        IAccessManager(address(authority)).grantRole(AccessRolesLib.HOST_PROXY_FACTORY_DEPLOYER, address(this), 0);
    }
}
