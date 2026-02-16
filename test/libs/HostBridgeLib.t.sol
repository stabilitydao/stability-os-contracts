// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
import {HostBridgeLib} from "../../src/libs/HostBridgeLib.sol";
import {Authority} from "../../src/Authority.sol";
import {HostConfigLib} from "../../src/libs/HostConfigLib.sol";
import {HostEncodingLib} from "../../src/libs/HostEncodingLib.sol";
import {HostLib} from "../../src/libs/HostLib.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {IBridgedActions} from "../../src/interfaces/IBridgedActions.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";
import {MockHost} from "../mocks/MockHost.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {Test} from "forge-std/Test.sol";
import {SampleDataLib} from "../utils/SampleDataLib.sol";
import {HostCrossChainLib} from "../../src/libs/HostCrossChainLib.sol";

contract HostBridgeLibTest is Test {
    MockERC20 internal exchangeAsset;

    /// @dev msg.sender (it cannot be changed by vm.prank in library calls)
    address internal user;
    address public multisig;
    IAuthority public authority;

    /// @dev Default claim = block.timestamp + offset
    uint public constant DEFAULT_CLAIM_OFFSET = 2 days;

    constructor() {
        multisig = makeAddr("multisig");
        authority = _createAuthority();

        /// @dev We call library directly, internal msg.sender is not overwritten by vm.prank
        user = msg.sender;
        exchangeAsset = new MockERC20("Exchange Asset", "EXA", 18);

        HostConfigLib.getHostChainSettings().exchangeAsset = address(exchangeAsset);
    }

    //region ------------------------------------------ Tests for applyBridgedAction
    function testApplyBridgedAction_Normal_Success() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        uint daoUid = 97;
        bytes32 proposalId = "0x11111";
        IBridgedActions.BridgeDaoParams memory p = SampleDataLib.getBridgeDaoParams();

        bytes memory payload = HostEncodingLib.encodeBridgeDaoParams(p, HostEncodingLib.PAYLOAD_API_VERSION);
        bytes32 payloadHash = HostBridgeLib._getHashProposalAction(proposalId, payload);

        $.bridgedActionHashes[payloadHash].daoUid = daoUid;
        $.bridgedActionHashes[payloadHash].bridgedActionHeader = HostLib.packBridgedActionHeader(
            HostLib.BridgedActionHeader({actionKind: uint16(IHost.BridgedActions.BRIDGE_DAO_1), applied: false})
        );

        this.applyBridgedActionPublic(proposalId, payload);

        // ---------------------- Verify storage state
        HostLib.BridgedActionHeader memory headerAfter =
            HostLib.unpackBridgedActionHeader($.bridgedActionHashes[payloadHash].bridgedActionHeader);
        assertEq(
            headerAfter.actionKind == uint16(IHost.BridgedActions.BRIDGE_DAO_1),
            true,
            "Action kind should remain the same"
        );
        assertEq(headerAfter.applied, true, "Action should be marked as applied");
    }

    function testApplyBridgedAction_AlreadyApplied_Revert() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        uint daoUid = 97;
        bytes32 proposalId = "0x11111";
        IBridgedActions.BridgeDaoParams memory p = SampleDataLib.getBridgeDaoParams();

        bytes memory payload = HostEncodingLib.encodeBridgeDaoParams(p, HostEncodingLib.PAYLOAD_API_VERSION);
        bytes32 payloadHash = HostBridgeLib._getHashProposalAction(proposalId, payload);

        $.bridgedActionHashes[payloadHash].daoUid = daoUid;
        $.bridgedActionHashes[payloadHash].bridgedActionHeader = HostLib.packBridgedActionHeader(
            HostLib.BridgedActionHeader({actionKind: uint16(IHost.BridgedActions.BRIDGE_DAO_1), applied: false})
        );

        this.applyBridgedActionPublic(proposalId, payload);

        vm.expectRevert(IHost.BridgedActionAlreadyApplied.selector);
        this.applyBridgedActionPublic(proposalId, payload);
    }

    function testApplyBridgedAction_WrongHash_Revert() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        uint daoUid = 97;
        bytes32 proposalId = "0x11111";
        IBridgedActions.BridgeDaoParams memory p = SampleDataLib.getBridgeDaoParams();

        bytes memory payload = HostEncodingLib.encodeBridgeDaoParams(p, HostEncodingLib.PAYLOAD_API_VERSION);
        bytes32 payloadHash = HostBridgeLib._getHashProposalAction("0x22222", payload);

        $.bridgedActionHashes[payloadHash].daoUid = daoUid;
        $.bridgedActionHashes[payloadHash].bridgedActionHeader = HostLib.packBridgedActionHeader(
            HostLib.BridgedActionHeader({actionKind: uint16(IHost.BridgedActions.BRIDGE_DAO_1), applied: false})
        );

        vm.expectRevert(IHost.UnknownBridgedActionHash.selector);
        this.applyBridgedActionPublic(proposalId, payload);
    }

    function testApplyBridgedAction_WrongPayload_Revert() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        uint daoUid = 97;
        bytes32 proposalId = "0x11111";
        IBridgedActions.BridgeDaoParams memory p = SampleDataLib.getBridgeDaoParams();

        bytes memory payload = HostEncodingLib.encodeBridgeDaoParams(p, HostEncodingLib.PAYLOAD_API_VERSION);
        bytes32 payloadHash = HostBridgeLib._getHashProposalAction(proposalId, payload);

        $.bridgedActionHashes[payloadHash].daoUid = daoUid;
        $.bridgedActionHashes[payloadHash].bridgedActionHeader = HostLib.packBridgedActionHeader(
            HostLib.BridgedActionHeader({actionKind: uint16(IHost.BridgedActions.BRIDGE_DAO_1), applied: false})
        );

        p.name = "p is changed!";
        bytes memory wrongPayload = HostEncodingLib.encodeBridgeDaoParams(p, HostEncodingLib.PAYLOAD_API_VERSION);

        vm.expectRevert(IHost.UnknownBridgedActionHash.selector);
        this.applyBridgedActionPublic(proposalId, wrongPayload);
    }
    //endregion ------------------------------------------ Tests for applyBridgedAction

    //region ------------------------------------------ Tests for validation

    function testVerifyBridgedActionBridgeDao_Normal_Success() public {
        uint daoUid = 97;

        IBridgedActions.BridgeDaoParams memory p;
        p.symbol = "a";
        p.name = "b";
        p.unitIds = new string[](1);
        p.unitIds[0] = "unitId";

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.DaoDataSegment2 storage segment2 = $.segment2[daoUid];
        segment2.symbol = "a";
        segment2.name = "b";

        $.units[HostLib.getUnitKey(daoUid, "unitId")].daoUid = 97;

        for (uint i; i < uint(ITokenomics.LifecyclePhase.LIVE_CLIFF_6); ++i) {
            segment2.phase = ITokenomics.LifecyclePhase(i);
            this.verifyBridgedActionBridgeDaoPublic(daoUid, p);
        }
    }

    function testVerifyBridgedActionBridgeDao_WrongPhase_Revert() public {
        IBridgedActions.BridgeDaoParams memory p;
        p.symbol = "a";
        p.name = "b";
        p.unitIds = new string[](1);

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.DaoDataSegment2 storage segment2 = $.segment2[1];
        segment2.symbol = "a";
        segment2.name = "b";

        for (
            uint i = uint(ITokenomics.LifecyclePhase.LIVE_CLIFF_6);
            i < uint(ITokenomics.LifecyclePhase.COUNT_LIFECYCLE_PHASES);
            ++i
        ) {
            segment2.phase = ITokenomics.LifecyclePhase(i);

            vm.expectRevert(IHost.WrongAction.selector);
            this.verifyBridgedActionBridgeDaoPublic(1, p);
        }
    }

    function testVerifyBridgedActionBridgeDao_WrongSymbolName_Revert() public {
        IBridgedActions.BridgeDaoParams memory p;
        p.symbol = "a";
        p.name = "b";
        p.unitIds = new string[](1);

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.DaoDataSegment2 storage segment2 = $.segment2[1];
        segment2.phase = ITokenomics.LifecyclePhase.DRAFT_0;

        segment2.symbol = "not-a";
        segment2.name = "b";
        vm.expectRevert(IHost.IncorrectInputData.selector);
        this.verifyBridgedActionBridgeDaoPublic(1, p);

        segment2.symbol = "a";
        segment2.name = "not-b";
        vm.expectRevert(IHost.IncorrectInputData.selector);
        this.verifyBridgedActionBridgeDaoPublic(1, p);
    }

    function testVerifyBridgedActionBridgeDao_NoUnitsToBridge_Revert() public {
        IBridgedActions.BridgeDaoParams memory p;
        p.symbol = "a";
        p.name = "b";

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.DaoDataSegment2 storage segment2 = $.segment2[1];
        segment2.phase = ITokenomics.LifecyclePhase.DRAFT_0;
        segment2.symbol = "a";
        segment2.name = "b";

        p.unitIds = new string[](0); // (!)

        vm.expectRevert(IHost.UnitsRequired.selector);
        this.verifyBridgedActionBridgeDaoPublic(1, p);
    }

    function testVerifyBridgedActionBridgeDao_NotRegisteredUnit_Revert() public {
        uint daoUid = 97;

        IBridgedActions.BridgeDaoParams memory p;
        p.symbol = "a";
        p.name = "b";
        p.unitIds = new string[](2);
        p.unitIds[0] = "unitId1";
        p.unitIds[1] = "unitId2";

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        HostLib.DaoDataSegment2 storage segment2 = $.segment2[daoUid];
        segment2.symbol = "a";
        segment2.name = "b";
        segment2.phase = ITokenomics.LifecyclePhase.DRAFT_0;

        $.units[HostLib.getUnitKey(daoUid, "unitId1")].daoUid = 97; // only unit1 is registered, unit2 is not registered

        vm.expectRevert(IHost.UnitNotFound.selector);
        this.verifyBridgedActionBridgeDaoPublic(daoUid, p);
    }
    //endregion ------------------------------------------ Tests for validation

    //region ------------------------------------------ Tests for _applyBridgedAction

    function test_applyBridgedAction_BridgedDao_Success() public {
        uint daoUid = 97;
        IBridgedActions.BridgeDaoParams memory p = SampleDataLib.getBridgeDaoParams();

        bytes memory payload = HostEncodingLib.encodeBridgeDaoParams(p, HostEncodingLib.PAYLOAD_API_VERSION);
        this.applyBridgedActionPublic(daoUid, IHost.BridgedActions.BRIDGE_DAO_1, payload);

        // ---------------------- Verify storage state
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        assertEq($.daoUids[p.symbol], daoUid, "DAO UID should be mapped to symbol");
        assertEq($.segment2[daoUid].symbol, p.symbol, "Symbol should be stored in segment2");
    }

    function test_applyBridgedAction_BridgedUnits_Success() public {
        uint daoUid = 97;
        string[] memory units = new string[](2);
        units[0] = "UnitA";
        units[1] = "UnitB";

        IBridgedActions.BridgedUnits memory p = IBridgedActions.BridgedUnits({unitIds: units});
        bytes memory payload = HostEncodingLib.encodeBridgedUnits(p, HostEncodingLib.PAYLOAD_API_VERSION);

        this.applyBridgedActionPublic(daoUid, IHost.BridgedActions.SET_BRIDGED_UNITS_2, payload);

        // ---------------------- Verify storage state
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        assertEq($.segment2[daoUid].unitIds.length, 2, "Unit array length mismatch");
        assertEq($.segment2[daoUid].unitIds[0], "UnitA", "First unit ID mismatch");
    }

    function test_applyBridgedAction_DaoParameters_Success() public {
        uint daoUid = 97;
        ITokenomics.DaoParameters memory p = SampleDataLib.getDaoParameters();
        bytes memory payload = HostEncodingLib.encodeDaoParameters(p, HostEncodingLib.PAYLOAD_API_VERSION);

        this.applyBridgedActionPublic(daoUid, IHost.BridgedActions.SET_DAO_PARAMS_4, payload);

        // ---------------------- Verify storage state
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        assertEq($.daoParameters[daoUid].totalSupply, p.totalSupply, "Total supply parameter mismatch");
    }

    function test_applyBridgedAction_Salts_Success() public {
        uint daoUid = 97;
        (uint16[] memory indices, bytes32[] memory salts) = SampleDataLib.getSalts();
        bytes memory payload = HostEncodingLib.encodeSalt(indices, salts, HostEncodingLib.PAYLOAD_API_VERSION);

        this.applyBridgedActionPublic(daoUid, IHost.BridgedActions.SET_SALTS_5, payload);

        // ---------------------- Verify storage state
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        assertEq($.salt[HostLib.getKey(daoUid, indices[0])], salts[0], "Contract salt mismatch");
        assertEq($.daoUidBySalt[salts[0]], daoUid, "Salt to UID mapping mismatch");
    }

    function test_applyBridgedAction_ChainSettings_Success() public {
        uint daoUid = 97;
        ITokenomics.DaoChainSettings memory p = SampleDataLib.getDaoChainSettings();
        bytes memory payload = HostEncodingLib.encodeDaoChainSettings(p, HostEncodingLib.PAYLOAD_API_VERSION);

        this.applyBridgedActionPublic(daoUid, IHost.BridgedActions.UPDATE_CHAIN_SETTINGS_6, payload);

        // ---------------------- Verify storage state
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        assertEq($.chainSettings[daoUid].bbRate, p.bbRate, "bbRate setting mismatch");
    }

    //endregion ------------------------------------------ Tests for _applyBridgedAction

    //region ------------------------------------------ Tests for applying bridged actions
    function testApplyBridgeDaoUpdate_SymbolAlreadyRegistered_Success() public {
        uint daoUid = 97;

        // Only DAO symbol is registered on chain, other data is not set
        HostCrossChainLib.onReceiveCrossChainMessage(1, "0x1", HostCrossChainLib.packMessageNewDaoSymbol("SYMBOL"));

        IBridgedActions.BridgeDaoParams memory p = SampleDataLib.getBridgeDaoParams();

        this.applyBridgeDaoUpdatePublic(daoUid, p);

        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        assertEq($.daoUids[p.symbol], daoUid, "DaoUid is set for symbol");

        HostLib.DaoDataSegment2 storage segment2 = $.segment2[daoUid];
        assertEq(segment2.symbol, p.symbol, "DAO symbol is updated");
        assertEq(segment2.name, p.name, "DAO name is updated");
        assertEq(segment2.unitIds, p.unitIds, "unitIds are set");

        assertTrue(segment2.phase == ITokenomics.LifecyclePhase.DRAFT_0, "DAO phase is set to DRAFT");

        assertEq(abi.encode($.daoParameters[daoUid]), abi.encode(p.daoParameters), "daoParameters");
        assertEq(abi.encode($.chainSettings[daoUid]), abi.encode(p.chainSettings), "chainSettings");

        for (uint i; i < p.saltContractIndices.length; ++i) {
            assertEq($.salt[HostLib.getKey(daoUid, p.saltContractIndices[i])], p.salts[i], "correct salt");
            assertEq($.daoUidBySalt[p.salts[i]], daoUid, "salt is marked as used");
        }
    }

    function testApplyBridgeDaoUpdate_SymbolNotRegistered_Success() public {
        uint daoUid = 97;

        // HostCrossChainLib.onReceiveCrossChainMessage(1, "0x1", HostCrossChainLib.packMessageNewDaoSymbol("SYMBOL"));

        IBridgedActions.BridgeDaoParams memory p = SampleDataLib.getBridgeDaoParams();
        this.applyBridgeDaoUpdatePublic(daoUid, p);
    }

    function testApplyBridgeDaoUpdate_DaoAlreadyBridged_Revert() public {
        uint daoUid = 97;

        // Only DAO symbol is registered on chain, other data is not set
        HostCrossChainLib.onReceiveCrossChainMessage(1, "0x1", HostCrossChainLib.packMessageNewDaoSymbol("SYMBOL"));

        IBridgedActions.BridgeDaoParams memory p = SampleDataLib.getBridgeDaoParams();

        this.applyBridgeDaoUpdatePublic(daoUid, p);

        vm.expectRevert(IHost.AlreadyBridged.selector);
        this.applyBridgeDaoUpdatePublic(daoUid, p);
    }

    function testApplyBridgeDaoUpdate_SaltAlreadyUsedByOtherDAO_Revert() public {
        uint daoUid = 97;

        // Only DAO symbol is registered on chain, other data is not set
        HostCrossChainLib.onReceiveCrossChainMessage(1, "0x1", HostCrossChainLib.packMessageNewDaoSymbol("SYMBOL"));

        IBridgedActions.BridgeDaoParams memory p = SampleDataLib.getBridgeDaoParams();

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUidBySalt[p.salts[0]] = daoUid + 1;

        vm.expectRevert(abi.encodeWithSelector(IHost.SaltAlreadyUsed.selector, p.salts[0]));
        this.applyBridgeDaoUpdatePublic(daoUid, p);
    }

    function testApplyBridgeDaoUpdate_SaltAlreadyUsedByTheDAO_Revert() public {
        uint daoUid = 97;

        IBridgedActions.BridgeDaoParams memory p = SampleDataLib.getBridgeDaoParams();

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUidBySalt[p.salts[0]] = daoUid;

        // it's not real case
        // the dao is not registered on the bridged chain
        // so, salt cannot be used by the dao
        vm.expectRevert(abi.encodeWithSelector(IHost.SaltAlreadyUsed.selector, p.salts[0]));
        this.applyBridgeDaoUpdatePublic(daoUid, p);
    }

    function testApplyBridgedUnits() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment2[daoUid].unitIds = new string[](2);
        $.segment2[daoUid].unitIds[0] = "unit-1";
        $.segment2[daoUid].unitIds[1] = "unit-2";

        IBridgedActions.BridgedUnits memory p;
        p.unitIds = new string[](3);
        p.unitIds[0] = "unit-2"; // existing unit
        p.unitIds[1] = "unit-3"; // new unit
        p.unitIds[2] = "unit-4"; // new unit

        HostBridgeLib._applyBridgedUnits(daoUid, p);

        string[] memory units = $.segment2[daoUid].unitIds;
        assertEq(units, p.unitIds, "New list of units is correctly set");
    }

    function testApplyDaoChainSettingsUpdate() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.DaoChainSettings memory p = SampleDataLib.getDaoChainSettings();
        this.applyDaoChainSettingsUpdatePublic(daoUid, p);

        assertEq(abi.encode($.chainSettings[daoUid]), abi.encode(p), "chainSettings are updated");
    }

    function testApplyDaoParametersUpdate() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.DaoParameters memory p = SampleDataLib.getDaoParameters();
        this.applyDaoParametersUpdatePublic(daoUid, p);

        assertEq(abi.encode($.daoParameters[daoUid]), abi.encode(p), "Dao parameters are updated");
    }

    function testApplySaltsUpdate_SaltIsNotUsed_Success() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        (uint16[] memory contractIndices, bytes32[] memory salt) = SampleDataLib.getSalts();
        this.applySaltsUpdatePublic(daoUid, contractIndices, salt);

        for (uint i; i < contractIndices.length; ++i) {
            assertEq($.salt[HostLib.getKey(daoUid, contractIndices[i])], salt[i], "correct salt");
            assertEq($.daoUidBySalt[salt[i]], daoUid, "salt is marked as used");
        }
    }

    function testApplySaltsUpdate_SaltIsAlreadyUsedByTheDAO_Success() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        (uint16[] memory contractIndices, bytes32[] memory salt) = SampleDataLib.getSalts();
        for (uint i; i < contractIndices.length; ++i) {
            $.daoUidBySalt[salt[i]] = daoUid;
        }

        this.applySaltsUpdatePublic(daoUid, contractIndices, salt);

        for (uint i; i < contractIndices.length; ++i) {
            assertEq($.salt[HostLib.getKey(daoUid, contractIndices[i])], salt[i], "correct salt");
            assertEq($.daoUidBySalt[salt[i]], daoUid, "salt is marked as used");
        }
    }

    function testApplySaltsUpdate_SaltIsAlreadyUsedByAnotherDAO_Revert() public {
        uint daoUid = 97;
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        (uint16[] memory contractIndices, bytes32[] memory salts) = SampleDataLib.getSalts();
        for (uint i; i < contractIndices.length; ++i) {
            $.daoUidBySalt[salts[i]] = daoUid + 100; // (!)
        }

        vm.expectRevert(abi.encodeWithSelector(IHost.SaltAlreadyUsed.selector, salts[0]));
        this.applySaltsUpdatePublic(daoUid, contractIndices, salts);
    }

    //endregion ------------------------------------------ Tests for applying bridged actions

    //region ------------------------------------------ External access to library functions
    function verifyBridgedActionBridgeDaoPublic(uint daoUid, IBridgedActions.BridgeDaoParams memory p) public view {
        HostBridgeLib._verifyBridgedActionBridgeDao(daoUid, p);
    }

    function applyBridgeDaoUpdatePublic(uint daoUid, IBridgedActions.BridgeDaoParams memory p) public {
        HostBridgeLib._applyBridgeDaoUpdate(daoUid, p);
    }

    function applyDaoChainSettingsUpdatePublic(uint daoUid, ITokenomics.DaoChainSettings memory p) external {
        HostBridgeLib._applyDaoChainSettingsUpdate(daoUid, p);
    }

    function applyDaoParametersUpdatePublic(uint daoUid, ITokenomics.DaoParameters memory daoParameters) external {
        HostBridgeLib._applyDaoParametersUpdate(daoUid, daoParameters);
    }

    function applySaltsUpdatePublic(uint daoUid, uint16[] memory contractIndices, bytes32[] memory salt) external {
        HostBridgeLib._applySaltsUpdate(daoUid, contractIndices, salt);
    }

    function applyBridgedActionPublic(bytes32 proposalId, bytes calldata actionPayload) external {
        HostBridgeLib.applyBridgedAction(proposalId, actionPayload);
    }

    function applyBridgedActionPublic(
        uint daoUid,
        IHost.BridgedActions actionKind,
        bytes calldata actionPayload
    ) external {
        HostBridgeLib._applyBridgedAction(daoUid, actionKind, actionPayload);
    }

    //endregion ------------------------------------------ External access to library functions

    //region ------------------------------------------ Internal logic
    function _createAuthority() internal returns (IAuthority) {
        vm.prank(multisig);
        ProxyFactory proxyFactory = new ProxyFactory();

        MockHost _host = new MockHost();

        Authority _authority = new Authority(multisig, address(_host), address(proxyFactory));

        vm.prank(multisig);
        proxyFactory.setWhitelisted(address(_authority), true);

        return _authority;
    }

    //endregion ------------------------------------------ Internal logic
}
