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

    // todo
    function testChangePhase_Draft_Success() internal {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["dao"] = daoUid;
        $.segment2[daoUid].phase = ITokenomics.LifecyclePhase.DRAFT_0;

        _solveTasks(daoUid, ITokenomics.LifecyclePhase.DRAFT_0);
        $.salt[HostLib.getKey(daoUid, uint16(ITokenomics.ContractIndices.SEED_TOKEN_1))] = "0x9743733";

        HostProxyLib.HostProxyStorage storage $proxy = HostProxyLib.getHostProxyStorage();
        $proxy.implementations[uint(ITokenomics.ContractIndices.SEED_TOKEN_1)] = address(seedToken);

        this.changePhase("dao", address(authority));
    }

    //endregion ---------------------------- ChangePhase

    //region ------------------------------------------ Test utils
    function _solveTasks(uint daoUid, ITokenomics.LifecyclePhase phase) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        if (phase == ITokenomics.LifecyclePhase.DRAFT_0) {
            // Need images of token and seedToken
            $.daoImages[daoUid].seedToken = "a";
            $.daoImages[daoUid].token = "b";
            // Need at least 2 socials
            $.segment3[daoUid].socials = new string[](2);
            // Need at least 1 projected unit
            $.segment2[daoUid].unitIds = new string[](1);
        }
    }

    //endregion ------------------------------------------ Test utils

    //region ---------------------------- External access to library functions
    function changePhase(string calldata symbol, address authority_) public {
        HostActionsLib.changePhase(symbol, authority_);
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
