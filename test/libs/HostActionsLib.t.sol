// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";
import {HostLib} from "../../src/libs/HostLib.sol";
import {Test} from "forge-std/Test.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {ISeedToken} from "../../src/interfaces/ISeedToken.sol";
import {ITgeToken} from "../../src/interfaces/ITgeToken.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {SeedToken} from "../../src/tokenomics/SeedToken.sol";
import {TgeToken} from "../../src/tokenomics/TgeToken.sol";
import {HostActionsLib} from "../../src/libs/HostActionsLib.sol";
import {Authority} from "../../src/Authority.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {MockHost} from "../mocks/MockHost.sol";
import {HostConfigLib} from "../../src/libs/HostConfigLib.sol";
import {HostViewLib} from "../../src/libs/HostViewLib.sol";
import {HostProxyLib} from "../../src/libs/HostProxyLib.sol";

contract HostActionsLibTest is Test {
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

    //region ---------------------------- ChangePhase
    function testChangePhase_UnknownUid_Revert() public {
        // HostLib.HostStorage storage $ = HostLib.getHostStorage();
        vm.expectRevert(IHost.IncorrectDao.selector);
        this.changePhase("unknown", address(authority));
    }

    function testChangePhase_UnresolvedTask_Revert() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["dao"] = daoUid;

        assertTrue(HostViewLib._tasks(1, daoUid).length != 0, "there are unsolved tasks");

        vm.expectRevert(IHost.SolveTasksFirst.selector);
        this.changePhase("dao", address(authority));
    }

    function testChangePhaseDraft_Success_ReturnSeed() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.Funding storage seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
        seed.start = uint64(block.timestamp - 1);

        // allow to deploy seed token
        $.salt[HostLib.getKey(daoUid, uint16(ITokenomics.ContractIndices.SEED_TOKEN_1))] = "0x9743733";
        HostProxyLib.HostProxyStorage storage $proxy = HostProxyLib.getHostProxyStorage();
        $proxy.implementations[uint(ITokenomics.ContractIndices.SEED_TOKEN_1)] = address(new SeedToken());

        assertEq(uint(this.changePhaseDraft(daoUid)), uint(ITokenomics.LifecyclePhase.SEED_1), "next phase is seed");

        assertNotEq($.deployments[daoUid].seedToken, address(0), "seed token deployed");
    }

    function testChangePhaseDraft_TooEarly_Revert() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.Funding storage seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];
        seed.start = uint64(block.timestamp);

        vm.expectRevert(IHost.WaitFundingStart.selector);
        this.changePhaseDraft(daoUid);

        seed.start = uint64(block.timestamp) + 1;

        vm.expectRevert(IHost.WaitFundingStart.selector);
        this.changePhaseDraft(daoUid);
    }

    function testChangePhaseSeed_Success_ReturnDevelopment() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.Funding storage seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];

        seed.end = uint64(block.timestamp);
        seed.minRaise = 100;
        seed.raised = 100;

        assertEq(uint(this.changePhaseSeed(daoUid)), uint(ITokenomics.LifecyclePhase.DEVELOPMENT_3), "next phase is Development");

        seed.raised = 101;
        seed.end = uint64(block.timestamp - 1);
        assertEq(uint(this.changePhaseSeed(daoUid)), uint(ITokenomics.LifecyclePhase.DEVELOPMENT_3), "next phase is Development");
    }

    function testChangePhaseSeed_TooEarly_Revert() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.Funding storage seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];

        seed.end = uint64(block.timestamp) + 1;
        seed.minRaise = 100;
        seed.raised = 100;

        vm.expectRevert(IHost.WaitFundingEnd.selector);
        this.changePhaseSeed(daoUid);
    }

    function testChangePhaseSeed_RaiseTooLow_ReturnSeedFailed() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.Funding storage seed = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.SEED_0))];

        seed.end = uint64(block.timestamp) - 1;
        seed.minRaise = 100;
        seed.raised = 99;

        assertEq(uint(this.changePhaseSeed(daoUid)), uint(ITokenomics.LifecyclePhase.SEED_FAILED_2), "next phase is Seed Failed");
    }

    function testChangePhaseDevelopment_Success_ReturnDevelopment() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

        // allow to deploy TGE token
        $.salt[HostLib.getKey(daoUid, uint16(ITokenomics.ContractIndices.TGE_TOKEN_2))] = "0x34";
        HostProxyLib.HostProxyStorage storage $proxy = HostProxyLib.getHostProxyStorage();
        $proxy.implementations[uint(ITokenomics.ContractIndices.TGE_TOKEN_2)] = address(new TgeToken());

        for (uint i = 0; i < 2; ++i) {
            uint snapshot = vm.snapshotState();
            tge.end = uint64(block.timestamp - i);
            assertEq(uint(this.changePhaseDevelopment(daoUid)), uint(ITokenomics.LifecyclePhase.TGE_4), "next phase is TGE");
            assertNotEq($.deployments[daoUid].tgeToken, address(0), "TGE token deployed");
            vm.revertToState(snapshot);
        }
    }

    function testChangePhaseDevelopment_TooEarly_Revert() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

        tge.start = uint64(block.timestamp) + 1;

        vm.expectRevert(IHost.WaitFundingStart.selector);
        this.changePhaseDevelopment(daoUid);
    }

    function testChangePhaseTge_Success_ReturnLiveCliff() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

        // todo: set up contract implementations for token, xToken, staking, daoToken

        uint snapshot = vm.snapshotState();
        tge.end = uint64(block.timestamp);
        tge.minRaise = 100;
        tge.raised = 100;
        assertEq(uint(this.changePhaseTge(daoUid)), uint(ITokenomics.LifecyclePhase.LIVE_CLIFF_5), "next phase is Life Cliff 1");
        vm.revertToState(snapshot);

        tge.raised = 101;
        tge.end = uint64(block.timestamp - 1);
        assertEq(uint(this.changePhaseTge(daoUid)), uint(ITokenomics.LifecyclePhase.LIVE_CLIFF_5), "next phase is Live Cliff 2");

        // todo: check all deployed addresses
    }

    function testChangePhaseTge_TooEarly_Revert() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

        tge.end = uint64(block.timestamp) + 1;
        tge.minRaise = 100;
        tge.raised = 100;

        vm.expectRevert(IHost.WaitFundingEnd.selector);
        this.changePhaseTge(daoUid);
    }

    function testChangePhaseTge_RaiseTooLow_ReturnDevelopment() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.Funding storage tge = $.funding[HostLib.getKey(daoUid, uint(ITokenomics.FundingType.TGE_1))];

        tge.end = uint64(block.timestamp) - 1;
        tge.minRaise = 100;
        tge.raised = 99;

        assertEq(uint(this.changePhaseTge(daoUid)), uint(ITokenomics.LifecyclePhase.DEVELOPMENT_3), "next phase is Development");
    }

    function testChangePhaseLiveCliff_SingleStartedVesting_ReturnLiveVesting() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment3[daoUid].countVesting = 1;

        $.vesting[HostLib.getKey(daoUid, 0)].start = uint64(block.timestamp - 1);

        assertEq(uint(this.changePhaseLiveCliff(daoUid)), uint(ITokenomics.LifecyclePhase.LIVE_VESTING_6), "next phase is LIVE_VESTING_6");
    }

    function testChangePhaseLiveCliff_OneStartedOneNotStartedVesting_ReturnLiveVesting() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment3[daoUid].countVesting = 2;

        $.vesting[HostLib.getKey(daoUid, 0)].start = uint64(block.timestamp - 1); // started
        $.vesting[HostLib.getKey(daoUid, 1)].start = uint64(block.timestamp + 1); // not started

        assertEq(uint(this.changePhaseLiveCliff(daoUid)), uint(ITokenomics.LifecyclePhase.LIVE_VESTING_6), "next phase is LIVE_VESTING_6");
    }

    function testChangePhaseLiveCliff_SingleNotStartedVesting_Revert() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment3[daoUid].countVesting = 1;
        $.vesting[HostLib.getKey(daoUid, 0)].start = uint64(block.timestamp); // not started

        vm.expectRevert(IHost.WaitVestingStart.selector);
        this.changePhaseLiveCliff(daoUid);

        $.vesting[HostLib.getKey(daoUid, 0)].start = uint64(block.timestamp + 1); // not started

        vm.expectRevert(IHost.WaitVestingStart.selector);
        this.changePhaseLiveCliff(daoUid);

    }

    function testChangePhaseLiveVesting_SingleEndedVesting_ReturnLive() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment3[daoUid].countVesting = 1;

        $.vesting[HostLib.getKey(daoUid, 0)].end = uint64(block.timestamp - 1); // ended

        assertEq(uint(this.changePhaseLiveVesting(daoUid)), uint(ITokenomics.LifecyclePhase.LIVE_7), "next phase is LIVE");
    }

    function testChangePhaseLiveVesting_OneEndedOneNotEndedVesting_Revert() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment3[daoUid].countVesting = 2;

        $.vesting[HostLib.getKey(daoUid, 0)].end = uint64(block.timestamp - 1); // ended
        $.vesting[HostLib.getKey(daoUid, 1)].end = uint64(block.timestamp + 1); // not ended

        vm.expectRevert(IHost.WaitVestingEnd.selector);
        this.changePhaseLiveVesting(daoUid);
    }

    function testChangePhaseLiveVesting_SingleNotEndedVesting_Revert() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment3[daoUid].countVesting = 1;
        $.vesting[HostLib.getKey(daoUid, 0)].end = uint64(block.timestamp + 1); // not ended

        vm.expectRevert(IHost.WaitVestingEnd.selector);
        this.changePhaseLiveVesting(daoUid);
    }

    //endregion ---------------------------- ChangePhase

    //region ------------------------------------------ Test utils


    //endregion ------------------------------------------ Test utils

    //region ---------------------------- External access to library functions
// solidity
    //region ---------------------------- External access to library functions
    function changePhase(string calldata symbol, address authority_) public {
        HostActionsLib.changePhase(symbol, authority_);
    }

    function changePhaseDraft(uint daoUid) public returns (ITokenomics.LifecyclePhase) {
        return HostActionsLib._changePhaseDraft(HostLib.getHostStorage(), daoUid, address(authority));
    }

    function changePhaseSeed(uint daoUid) public view returns (ITokenomics.LifecyclePhase) {
        return HostActionsLib._changePhaseSeed(HostLib.getHostStorage(), daoUid);
    }

    function changePhaseDevelopment(uint daoUid) public returns (ITokenomics.LifecyclePhase) {
        return HostActionsLib._changePhaseDevelopment(HostLib.getHostStorage(), daoUid, address(authority));
    }

    function changePhaseTge(uint daoUid) public returns (ITokenomics.LifecyclePhase) {
        return HostActionsLib._changePhaseTge(HostLib.getHostStorage(), daoUid, address(authority));
    }

    function changePhaseLiveCliff(uint daoUid) public view returns (ITokenomics.LifecyclePhase) {
        return HostActionsLib._changePhaseLiveCliff(HostLib.getHostStorage(), daoUid);
    }

    function changePhaseLiveVesting(uint daoUid) public view returns (ITokenomics.LifecyclePhase) {
        return HostActionsLib._changePhaseLiveVesting(HostLib.getHostStorage(), daoUid);
    }

    //endregion ---------------------------- External access to library functions

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

        vm.prank(multisig);
        proxyFactory.setWhitelisted(address(this), true);

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
