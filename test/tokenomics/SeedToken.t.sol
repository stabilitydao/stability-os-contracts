// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {console} from "forge-std/console.sol";
import {MockDataReader} from "../mocks/MockDataReader.sol";
import {MockHost} from "../mocks/MockHost.sol";
import {Test} from "forge-std/Test.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {ISeedToken} from "../../src/interfaces/ISeedToken.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {SeedToken} from "../../src/tokenomics/SeedToken.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";
import {AuthorityAccessUtils} from "../scenario/access/AuthorityAccessUtils.sol";

contract SeedTokenTest is Test {
    using SafeERC20 for IERC20;

    address public multisig;
    IAuthority public authority;
    address public host;
    MockDataReader public dataReader;

    constructor() {
        dataReader = new MockDataReader();
        multisig = makeAddr("multisig");
        authority = AuthorityAccessUtils.createAuthorityMockedHostWhitelistThis(vm, multisig);
        host = authority.HOST();
        MockHost(host).setDataReader(address(dataReader));
    }

    function testStorageLocation() internal pure {
        console.log("keccak256(abi.encode(uint(keccak256(erc7201:stability.host-contracts.SeedToken))))");
        console.logBytes32(
            keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.SeedToken")) - 1))
                & ~bytes32(uint(0xff))
        );
    }

    function testDaoUid() public {
        ISeedToken seedToken = _deploySeedToken(555);
        assertEq(seedToken.daoUid(), 555, "daoUid");
    }

    function testName() public {
        uint daoUid = 45427366;

        dataReader.setName(daoUid, uint(IHost.NamingTokenKind.SEED_0), "name");

        ISeedToken seedToken = _deploySeedToken(daoUid);
        assertEq(seedToken.name(), "name", "name before change");

        dataReader.setName(daoUid, uint(IHost.NamingTokenKind.SEED_0), "name2");
        assertEq(seedToken.name(), "name2", "name after change");
    }

    function testSymbol() public {
        uint daoUid = 45427366;

        dataReader.setSymbol(daoUid, uint(IHost.NamingTokenKind.SEED_0), "SYMBOL");

        ISeedToken seedToken = _deploySeedToken(daoUid);
        assertEq(seedToken.symbol(), "SYMBOL", "symbol before change");

        dataReader.setSymbol(daoUid, uint(IHost.NamingTokenKind.SEED_0), "SYMBOL2");
        assertEq(seedToken.symbol(), "SYMBOL2", "symbol after change");
    }

    function testMint() public {
        ISeedToken seedToken = _deploySeedToken(1);
        _setupAuthority(authority, address(seedToken));

        assertEq(seedToken.balanceOf(address(this)), 0, "balance before");

        seedToken.mint(address(this), 1e18);
        assertEq(seedToken.balanceOf(address(this)), 1e18, "balance after");
    }

    function testMint_NotAuthorized_Revert() public {
        ISeedToken seedToken = _deploySeedToken(1);

        vm.prank(makeAddr("not authorized"));
        vm.expectRevert(); // restricted
        seedToken.mint(address(this), 1e18);
    }

    function testGetVotes() public {
        ISeedToken seedToken = _deploySeedToken(1);
        _setupAuthority(authority, address(seedToken));

        assertEq(seedToken.getVotes(address(this)), 0, "votes before");

        seedToken.mint(address(this), 1e18);
        assertEq(seedToken.getVotes(address(this)), 1e18, "votes after");
    }

    function testRefund() public {
        ISeedToken seedToken = _deploySeedToken(1);
        _setupAuthority(authority, address(seedToken));

        // --------------------- add asset on seed token balance and seed token on user's balance
        MockERC20 asset = new MockERC20("Mock Asset", "MA", 18);
        asset.mint(address(seedToken), 50e18);
        seedToken.mint(address(this), 100e18);

        // --------------------- refund
        address receiver = makeAddr("receiver");
        seedToken.refund(address(this), 20e18, address(asset), receiver);

        assertEq(seedToken.balanceOf(address(this)), 80e18, "seed token balance after refund");
        assertEq(asset.balanceOf(receiver), 20e18, "asset balance of receiver after refund");
        assertEq(asset.balanceOf(address(seedToken)), 30e18, "asset balance of seed token");
    }

    function testRefund_NotAuthorized_Revert() public {
        ISeedToken seedToken = _deploySeedToken(1);
        _setupAuthority(authority, address(seedToken));

        MockERC20 asset = new MockERC20("Mock Asset", "MA", 18);
        asset.mint(address(seedToken), 50e18);
        seedToken.mint(address(this), 100e18);

        vm.prank(makeAddr("not authorized"));
        vm.expectRevert(); // AccessManagedUnauthorized
        seedToken.refund(address(this), 20e18, address(asset), makeAddr("receiver"));
    }

    function testTransferTo() public {
        address receiver = makeAddr("receiver");

        ISeedToken seedToken = _deploySeedToken(1);
        _setupAuthority(authority, address(seedToken));

        MockERC20 asset = new MockERC20("Mock Asset", "MA", 18);
        asset.mint(address(seedToken), 50e18);

        vm.expectRevert(IHosted.ZeroAmount.selector);
        seedToken.transferTo(address(asset), address(receiver), 0);

        vm.expectRevert(IHosted.ZeroAddress.selector);
        seedToken.transferTo(address(asset), address(0), 10e18);

        vm.expectRevert(abi.encodeWithSelector(IHosted.InsufficientBalance.selector, 50e18, 51e18));
        seedToken.transferTo(address(asset), address(receiver), 51e18);

        seedToken.transferTo(address(asset), address(receiver), 10e18);

        assertEq(seedToken.balanceOf(address(this)), 0, "seed token balance of user is not changed");
        assertEq(seedToken.balanceOf(receiver), 0, "seed token balance of receiver is not changed");

        assertEq(asset.balanceOf(receiver), 10e18, "asset balance of receiver after transfer");
        assertEq(asset.balanceOf(address(seedToken)), 40e18, "asset balance of seed token after transfer");

        seedToken.transferTo(address(asset), address(receiver), 40e18);
        assertEq(asset.balanceOf(receiver), 50e18, "asset balance of receiver after full transfer");
        assertEq(asset.balanceOf(address(seedToken)), 0, "asset balance of seed token after full transfer");
    }

    function testTransferTo_NotAuthorized_Revert() public {
        address receiver = makeAddr("receiver");

        ISeedToken seedToken = _deploySeedToken(1);
        _setupAuthority(authority, address(seedToken));

        MockERC20 asset = new MockERC20("Mock Asset", "MA", 18);
        asset.mint(address(seedToken), 50e18);

        vm.prank(makeAddr("not authorized"));
        vm.expectRevert(); // restricted
        seedToken.transferTo(address(asset), address(receiver), 10e18);
    }

    function testNotTransferable_TryToTransfer_Revert() public {
        address receiver = makeAddr("receiver");

        ISeedToken seedToken = _deploySeedToken(1);
        _setupAuthority(authority, address(seedToken));

        seedToken.mint(address(this), 1e18);

        vm.expectRevert(ISeedToken.NonTransferable.selector);
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        seedToken.transfer(receiver, 1e18);
    }

    //region ------------------------------------------ Internal logic
    function _deploySeedToken(uint daoUid) internal returns (ISeedToken seedToken) {
        address logic = address(new SeedToken());
        address proxyFactory = authority.PROXY_FACTORY();
        seedToken = ISeedToken(IProxyFactory(proxyFactory).predictAddress("0x62436"));

        vm.prank(multisig);
        authority.execute(
            proxyFactory,
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                ("0x62436", logic, abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(daoUid))))
            )
        );
    }

    function _setupAuthority(IAuthority authority_, address seedToken_) internal {
        AuthorityAccessUtils.setRestrictedAccess(
            vm,
            multisig,
            authority_,
            address(this),
            65871739,
            seedToken_,
            SeedToken.mint.selector,
            SeedToken.refund.selector,
            SeedToken.transferTo.selector
        );
    }

    //endregion ------------------------------------------ Internal logic
}
