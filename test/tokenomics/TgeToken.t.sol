// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {console} from "forge-std/console.sol";
import {Authority} from "../../src/Authority.sol";
import {MockDataReader} from "../mocks/MockDataReader.sol";
import {MockHost} from "../mocks/MockHost.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {Test} from "forge-std/Test.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {ITgeToken} from "../../src/interfaces/ITgeToken.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {TgeToken} from "../../src/tokenomics/TgeToken.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";

contract TgeTokenTest is Test {
    using SafeERC20 for IERC20;

    address public multisig;
    IAuthority public authority;
    address public host;
    MockDataReader public dataReader;

    constructor() {
        dataReader = new MockDataReader();
        multisig = makeAddr("multisig");
        authority = _createAuthorityWithMocks(address(dataReader));
        host = authority.HOST();
    }

    function testStorageLocation() internal pure {
        console.log("keccak256(abi.encode(uint(keccak256(erc7201:stability.host-contracts.TgeToken))))");
        console.logBytes32(
            keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.TgeToken")) - 1))
                & ~bytes32(uint(0xff))
        );
    }

    function testDaoUid() public {
        ITgeToken tgeToken = _deployTgeToken(555);
        assertEq(tgeToken.daoUid(), 555, "daoUid");
    }

    function testName() public {
        uint daoUid = 45427366;

        dataReader.setName(daoUid, uint(IHost.NamingTokenKind.TGE_1), "name");

        ITgeToken tgeToken = _deployTgeToken(daoUid);
        assertEq(tgeToken.name(), "name", "name before change");

        dataReader.setName(daoUid, uint(IHost.NamingTokenKind.TGE_1), "name2");
        assertEq(tgeToken.name(), "name2", "name after change");
    }

    function testSymbol() public {
        uint daoUid = 45427366;

        dataReader.setSymbol(daoUid, uint(IHost.NamingTokenKind.TGE_1), "SYMBOL");

        ITgeToken tgeToken = _deployTgeToken(daoUid);
        assertEq(tgeToken.symbol(), "SYMBOL", "symbol before change");

        dataReader.setSymbol(daoUid, uint(IHost.NamingTokenKind.TGE_1), "SYMBOL2");
        assertEq(tgeToken.symbol(), "SYMBOL2", "symbol after change");
    }

    function testMint() public {
        ITgeToken tgeToken = _deployTgeToken(1);
        _setupAuthority(authority, address(tgeToken));

        vm.prank(makeAddr("not authorized"));
        vm.expectRevert(); // restricted
        tgeToken.mint(address(this), 1e18);

        assertEq(tgeToken.balanceOf(address(this)), 0, "balance before");

        tgeToken.mint(address(this), 1e18);
        assertEq(tgeToken.balanceOf(address(this)), 1e18, "balance after");
    }

    function testRefund() public {
        ITgeToken tgeToken = _deployTgeToken(1);
        _setupAuthority(authority, address(tgeToken));

        // --------------------- add asset on tge token balance and tge token on user's balance
        MockERC20 asset = new MockERC20("Mock Asset", "MA", 18);
        asset.mint(address(tgeToken), 50e18);
        tgeToken.mint(address(this), 100e18);

        // --------------------- refund
        address receiver = makeAddr("receiver");
        tgeToken.refund(address(this), 20e18, address(asset), receiver);

        assertEq(tgeToken.balanceOf(address(this)), 80e18, "tge token balance after refund");
        assertEq(asset.balanceOf(receiver), 20e18, "asset balance of receiver after refund");
        assertEq(asset.balanceOf(address(tgeToken)), 30e18, "asset balance of tge token");
    }

    function testTransferable() public {
        address receiver = makeAddr("receiver");

        ITgeToken tgeToken = _deployTgeToken(1);
        _setupAuthority(authority, address(tgeToken));

        tgeToken.mint(address(this), 1e18);

        IERC20(address(tgeToken)).safeTransfer(receiver, 1e18);

        assertEq(tgeToken.balanceOf(receiver), 1e18, "receiver balance");
        assertEq(tgeToken.balanceOf(address(this)), 0, "sender balance");
    }

    //region ------------------------------------------ Internal logic
    function _deployTgeToken(uint daoUid) internal returns (ITgeToken tgeToken) {
        address logic = address(new TgeToken());
        address proxyFactory = authority.PROXY_FACTORY();
        tgeToken = ITgeToken(IProxyFactory(proxyFactory).predictAddress("0x62436"));

        vm.prank(multisig);
        authority.execute(
            proxyFactory,
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                ("0x62436", logic, abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(daoUid))))
            )
        );
    }

    function _createAuthorityWithMocks(address dataReader_) internal returns (IAuthority) {
        vm.prank(multisig);
        ProxyFactory proxyFactory = new ProxyFactory();

        MockHost _host = new MockHost();
        _host.setDataReader(dataReader_);

        Authority _authority = new Authority(multisig, address(_host), address(proxyFactory));

        vm.prank(multisig);
        proxyFactory.setWhitelisted(address(_authority), true);

        return _authority;
    }

    function _setupAuthority(IAuthority authority_, address tgeToken_) internal {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = bytes4(TgeToken.mint.selector);
        selectors[1] = bytes4(TgeToken.refund.selector);

        vm.prank(multisig);
        authority_.setTargetFunctionRole(tgeToken_, selectors, 65871739); // 65871739 = random role uid

        vm.prank(multisig);
        authority_.grantRole(65871739, multisig, 0);

        vm.prank(multisig);
        authority_.grantRole(65871739, address(this), 0);
    }

    //endregion ------------------------------------------ Internal logic
}
