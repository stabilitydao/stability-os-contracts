// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HostConfigLib} from "../../src/libs/HostConfigLib.sol";
import {HostFundingLib} from "../../src/libs/HostFundingLib.sol";
import {HostLib} from "../../src/libs/HostLib.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {ISeedToken} from "../../src/interfaces/ISeedToken.sol";
import {ITgeToken} from "../../src/interfaces/ITgeToken.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {SeedToken} from "../../src/tokenomics/SeedToken.sol";
import {TgeToken} from "../../src/tokenomics/TgeToken.sol";
import {MockHost} from "../mocks/MockHost.sol";
import {Authority} from "../../src/Authority.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
// import {console} from "forge-std/console.sol";

contract HostFundingLibTest is Test {
    MockERC20 internal exchangeAsset;
    address internal user;
    address internal seedToken;
    address internal tgeToken;
    address public multisig;
    IAuthority public authority;

    constructor() {
        multisig = makeAddr("multisig");
        authority = _createAuthority();

        /// @dev We call library directly, internal msg.sender is not overwritten by vm.prank
        user = msg.sender;
        exchangeAsset = new MockERC20("Exchange Asset", "EXA", 18);

        HostConfigLib.getHostChainSettings().exchangeAsset = address(exchangeAsset);

        seedToken = address(_deploySeedToken(1));
        tgeToken = address(_deployTgeToken(1));
        _setupAuthority(authority, seedToken, tgeToken);
    }

    //region ------------------------------------------ Fund tests
    function testFundSeedNormal() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["abc"] = 1;
        $.segment2[1].phase = ITokenomics.LifecyclePhase.SEED_1;
        $.funding[HostLib.getKey(1, uint(ITokenomics.FundingType.SEED_0))] = ITokenomics.Funding({
            fundingType: ITokenomics.FundingType.SEED_0,
            start: 0,
            end: 0,
            minRaise: 0,
            maxRaise: 1000e18,
            raised: 9e18,
            claim: 0
        });
        $.deployments[1].seedToken = address(seedToken);

        exchangeAsset.mint(user, 200e18);
        vm.prank(user);
        exchangeAsset.approve(address(this), 200e18);

        vm.prank(user); // just for clarification; internal msg.sender is not replaced in library call
        HostFundingLib.fund("abc", 11e18);

        ITokenomics.Funding storage seed = $.funding[HostLib.getKey(1, uint(ITokenomics.FundingType.SEED_0))];
        assertEq(seed.raised, 20e18, "raised amount");

        assertEq(exchangeAsset.balanceOf(address(seedToken)), 11e18, "all tokens transferred to seed token contract");
        assertEq(ISeedToken(seedToken).balanceOf(user), 11e18, "user got seed tokens");
    }

    function testFundTgeNormal() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["abc"] = 1;
        $.segment2[1].phase = ITokenomics.LifecyclePhase.TGE_4;
        $.funding[HostLib.getKey(1, uint(ITokenomics.FundingType.TGE_1))] = ITokenomics.Funding({
            fundingType: ITokenomics.FundingType.TGE_1,
            start: 0,
            end: 0,
            minRaise: 0,
            maxRaise: 1000e18,
            raised: 9e18,
            claim: 0
        });
        $.deployments[1].tgeToken = address(tgeToken);

        exchangeAsset.mint(user, 200e18);
        vm.prank(user);
        exchangeAsset.approve(address(this), 200e18);

        vm.prank(user); // just for clarification; internal msg.sender is not replaced in library call
        HostFundingLib.fund("abc", 11e18);

        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(1, uint(ITokenomics.FundingType.TGE_1))];
        assertEq(tge.raised, 20e18, "raised amount");

        assertEq(exchangeAsset.balanceOf(address(tgeToken)), 11e18, "all tokens transferred to tge token contract");
        assertEq(ITgeToken(tgeToken).balanceOf(user), 11e18, "user got tge tokens");
    }

    function testFundSeedMaxRaiseExceeded() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["abc"] = 1;
        $.segment2[1].phase = ITokenomics.LifecyclePhase.SEED_1;
        $.funding[HostLib.getKey(1, uint(ITokenomics.FundingType.SEED_0))] = ITokenomics.Funding({
            fundingType: ITokenomics.FundingType.SEED_0,
            start: 0,
            end: 0,
            minRaise: 0,
            maxRaise: 1000e18,
            raised: 1e18,
            claim: 0
        });
        $.deployments[1].seedToken = address(seedToken);

        exchangeAsset.mint(user, 1000e18);
        vm.prank(user);
        exchangeAsset.approve(address(this), 1000e18);

        vm.expectRevert(IHost.RaiseMaxExceed.selector);
        vm.prank(user); // just for clarification; internal msg.sender is not replaced in library call
        HostFundingLib.fund("abc", 1000e18);
    }

    function testFundTgeMaxRaiseExceeded() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["abc"] = 1;
        $.segment2[1].phase = ITokenomics.LifecyclePhase.TGE_4;
        $.funding[HostLib.getKey(1, uint(ITokenomics.FundingType.TGE_1))] = ITokenomics.Funding({
            fundingType: ITokenomics.FundingType.TGE_1,
            start: 0,
            end: 0,
            minRaise: 0,
            maxRaise: 1000e18,
            raised: 1e18,
            claim: 0
        });
        $.deployments[1].seedToken = address(tgeToken);

        exchangeAsset.mint(user, 1000e18);
        vm.prank(user);
        exchangeAsset.approve(address(this), 1000e18);

        vm.expectRevert(IHost.RaiseMaxExceed.selector);
        vm.prank(user); // just for clarification; internal msg.sender is not replaced in library call
        HostFundingLib.fund("abc", 1000e18);
    }

    function testFundTooLowFundAmount() public {
        HostConfigLib.getHostGlobalSettings().minFunding = 1e18;

        HostConfigLib.getHostGlobalSettings().minFundingRaise = 1e18;

        exchangeAsset.mint(user, 1e18);

        vm.prank(user);
        exchangeAsset.approve(address(this), 0.01e18);

        vm.prank(user);
        vm.expectRevert(IHost.TooLowValue.selector);
        HostFundingLib.fund("abc", 0.01e18);
    }

    function testFundNotFundingPhase() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["abc"] = 1;
        $.segment2[1].phase = ITokenomics.LifecyclePhase.DEVELOPMENT_3;

        exchangeAsset.mint(user, 1e18);
        vm.prank(user);
        exchangeAsset.approve(address(this), 1e18);

        vm.prank(user);
        vm.expectRevert(IHost.NotFundingPhase.selector);
        HostFundingLib.fund("abc", 1e18);
    }

    //endregion ------------------------------------------ Fund tests

    //region ------------------------------------------ Refund tests

    function testNotRefundPhases() public {
        _testNotRefundPhase(ITokenomics.LifecyclePhase.DRAFT_0);
        _testNotRefundPhase(ITokenomics.LifecyclePhase.SEED_1);
        _testNotRefundPhase(ITokenomics.LifecyclePhase.TGE_4);
        _testNotRefundPhase(ITokenomics.LifecyclePhase.LIVE_CLIFF_5);
        _testNotRefundPhase(ITokenomics.LifecyclePhase.LIVE_VESTING_6);
        _testNotRefundPhase(ITokenomics.LifecyclePhase.LIVE_7);
    }

    function testRefundSeedNormal() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["abc"] = 1;
        $.segment2[1].phase = ITokenomics.LifecyclePhase.SEED_FAILED_2;
        $.deployments[1].seedToken = address(seedToken);

        exchangeAsset.mint(address(seedToken), 900e18);

        /// @dev User has no seed tokens
        vm.prank(user); // just for clarification; internal msg.sender is not replaced in library call
        HostFundingLib.refund("abc");

        assertEq(exchangeAsset.balanceOf(user), 0, "user hasn't received any asset");
        assertEq(
            exchangeAsset.balanceOf(address(seedToken)), 900e18, "exchange asset balance of seed token is not changed"
        );

        ISeedToken(seedToken).mint(user, 100e18);

        vm.prank(user); // just for clarification; internal msg.sender is not replaced in library call
        HostFundingLib.refund("abc");

        assertEq(ISeedToken(seedToken).balanceOf(user), 0, "user seed token balance after refund");
        assertEq(exchangeAsset.balanceOf(user), 100e18, "user exchange asset balance after refund");
        assertEq(
            exchangeAsset.balanceOf(address(seedToken)),
            800e18,
            "seed token contract exchange asset balance after refund"
        );
    }

    function testRefundTgeNormal() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["abc"] = 1;
        $.segment2[1].phase = ITokenomics.LifecyclePhase.DEVELOPMENT_3;
        $.deployments[1].tgeToken = address(tgeToken);

        exchangeAsset.mint(address(tgeToken), 900e18);

        /// @dev User has no tge tokens
        vm.prank(user); // just for clarification; internal msg.sender is not replaced in library call
        HostFundingLib.refund("abc");

        assertEq(exchangeAsset.balanceOf(user), 0, "user hasn't received any asset");
        assertEq(
            exchangeAsset.balanceOf(address(tgeToken)), 900e18, "exchange asset balance of seed token is not changed"
        );

        ITgeToken(tgeToken).mint(user, 100e18);

        vm.prank(user); // just for clarification; internal msg.sender is not replaced in library call
        HostFundingLib.refund("abc");

        assertEq(ITgeToken(tgeToken).balanceOf(user), 0, "user TGE token balance after refund");
        assertEq(exchangeAsset.balanceOf(user), 100e18, "user exchange asset balance after refund");
        assertEq(
            exchangeAsset.balanceOf(address(tgeToken)), 800e18, "TGE token contract exchange asset balance after refund"
        );
    }

    function testRefundForTgeNormal() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["abc"] = 1;
        $.segment2[1].phase = ITokenomics.LifecyclePhase.DEVELOPMENT_3;
        $.deployments[1].tgeToken = address(tgeToken);

        exchangeAsset.mint(address(tgeToken), 1900e18);

        address[] memory users = new address[](3);
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
        users[2] = makeAddr("user3");

        ISeedToken(tgeToken).mint(users[0], 100e18);
        ISeedToken(tgeToken).mint(users[1], 800e18);
        ISeedToken(tgeToken).mint(users[2], 0); //user 3 has zero balance of seed tokens

        HostFundingLib.refundFor("abc", users);

        assertEq(ISeedToken(tgeToken).balanceOf(users[0]), 0, "user1 seed token balance after refund");
        assertEq(ISeedToken(tgeToken).balanceOf(users[1]), 0, "user2 seed token balance after refund");
        assertEq(ISeedToken(tgeToken).balanceOf(users[2]), 0, "user3 seed token balance after refund");

        assertEq(exchangeAsset.balanceOf(users[0]), 100e18, "receiver1 exchange asset balance after refund");
        assertEq(exchangeAsset.balanceOf(users[1]), 800e18, "receiver2 exchange asset balance after refund");
        assertEq(exchangeAsset.balanceOf(users[2]), 0, "receiver3 exchange asset balance after refund");

        assertEq(
            exchangeAsset.balanceOf(address(tgeToken)),
            1000e18,
            "seed token contract exchange asset balance after refund"
        );
    }

    function testRefundForSeedNormal() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["abc"] = 1;
        $.segment2[1].phase = ITokenomics.LifecyclePhase.SEED_FAILED_2;
        $.deployments[1].seedToken = address(seedToken);

        exchangeAsset.mint(address(seedToken), 1900e18);

        address[] memory users = new address[](3);
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
        users[2] = makeAddr("user3");

        ISeedToken(seedToken).mint(users[0], 100e18);
        ISeedToken(seedToken).mint(users[1], 800e18);
        ISeedToken(seedToken).mint(users[2], 0); //user 3 has zero balance of seed tokens

        HostFundingLib.refundFor("abc", users);

        assertEq(ISeedToken(seedToken).balanceOf(users[0]), 0, "user1 seed token balance after refund");
        assertEq(ISeedToken(seedToken).balanceOf(users[1]), 0, "user2 seed token balance after refund");
        assertEq(ISeedToken(seedToken).balanceOf(users[2]), 0, "user3 seed token balance after refund");

        assertEq(exchangeAsset.balanceOf(users[0]), 100e18, "receiver1 exchange asset balance after refund");
        assertEq(exchangeAsset.balanceOf(users[1]), 800e18, "receiver2 exchange asset balance after refund");
        assertEq(exchangeAsset.balanceOf(users[2]), 0, "receiver3 exchange asset balance after refund");

        assertEq(
            exchangeAsset.balanceOf(address(seedToken)),
            1000e18,
            "seed token contract exchange asset balance after refund"
        );
    }

    function _testNotRefundPhase(ITokenomics.LifecyclePhase notRefundPhases) internal {
        uint snapshot = vm.snapshotState();
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["abc"] = 1;
        $.segment2[1].phase = notRefundPhases;

        vm.prank(user); // just for clarification; internal msg.sender is not replaced in library call
        vm.expectRevert(IHost.NotRefundPhase.selector);
        HostFundingLib.refund("abc");

        vm.revertToState(snapshot);
    }

    //endregion ------------------------------------------ Refund tests

    //region ------------------------------------------ Internal logic

    function _deploySeedToken(uint daoUid) internal returns (ISeedToken _seedToken) {
        address logic = address(new SeedToken());
        address proxyFactory = authority.PROXY_FACTORY();
        _seedToken = ISeedToken(IProxyFactory(proxyFactory).predictAddress("0x375654"));

        vm.prank(multisig);
        authority.execute(
            proxyFactory,
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                ("0x375654", logic, abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(daoUid))))
            )
        );
    }

    function _deployTgeToken(uint daoUid) internal returns (ITgeToken _tgeToken) {
        address logic = address(new TgeToken());
        address proxyFactory = authority.PROXY_FACTORY();
        _tgeToken = ITgeToken(IProxyFactory(proxyFactory).predictAddress("0x62436"));

        vm.prank(multisig);
        authority.execute(
            proxyFactory,
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                ("0x62436", logic, abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(daoUid))))
            )
        );
    }

    function _createAuthority() internal returns (IAuthority) {
        vm.prank(multisig);
        ProxyFactory proxyFactory = new ProxyFactory();

        MockHost _host = new MockHost();

        Authority _authority = new Authority(multisig, address(_host), address(proxyFactory));

        vm.prank(multisig);
        proxyFactory.setWhitelisted(address(_authority), true);

        return _authority;
    }

    function _setupAuthority(IAuthority authority_, address seedToken_, address tgeToken_) internal {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = bytes4(SeedToken.mint.selector);
        selectors[1] = bytes4(SeedToken.refund.selector);
        selectors[2] = bytes4(SeedToken.transferTo.selector);

        vm.prank(multisig);
        authority_.setTargetFunctionRole(seedToken_, selectors, 65871739); // 65871739 = random role uid

        selectors = new bytes4[](2);
        selectors[0] = bytes4(TgeToken.mint.selector);
        selectors[1] = bytes4(TgeToken.refund.selector);

        vm.prank(multisig);
        authority_.setTargetFunctionRole(tgeToken_, selectors, 65871739);

        vm.prank(multisig);
        authority_.grantRole(65871739, multisig, 0);

        vm.prank(multisig);
        authority_.grantRole(65871739, address(this), 0);
    }

    //endregion ------------------------------------------ Internal logic
}
