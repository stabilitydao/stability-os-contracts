// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EfficientHashLib} from "@solady/utils/EfficientHashLib.sol";
import {IOAppReceiver} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReceiver.sol";
import {Vm, Test} from "forge-std/Test.sol";
import {SonicConstantsLib} from "../chains/SonicConstantsLib.sol";
import {AvalancheConstantsLib} from "../chains/AvalancheConstantsLib.sol";
import {BridgeTestLib} from "../test/utils/BridgeTestLib.sol";
import {IDAOData} from "../src/interfaces/IDAOData.sol";
import {IHost} from "../src/interfaces/IHost.sol";
import {ITokenomics} from "../src/interfaces/ITokenomics.sol";
import {ITokenomicsAddons} from "../src/interfaces/ITokenomicsAddons.sol";
import {IHostCodec} from "../src/interfaces/IHostCodec.sol";
import {IDAOMetadata} from "../src/interfaces/IDAOMetadata.sol";
import {IBridgedActions} from "../src/interfaces/IBridgedActions.sol";
import {IAuthority} from "../src/interfaces/IAuthority.sol";
import {HostUtilsLib} from "./utils/HostUtilsLib.sol";
import {HostEncodingLib} from "../src/libs/HostEncodingLib.sol";
import {console} from "forge-std/console.sol";

contract HostBridgedActionsTest is Test {
    uint private constant SONIC_FORK_BLOCK = 52228979; // Oct-28-2025 01:14:21 PM +UTC
    uint private constant AVALANCHE_FORK_BLOCK = 71037861; // Oct-28-2025 13:17:17 UTC

    address private constant TEST_DELEGATOR = address(0x9999);

    BridgeTestLib.ChainConfig internal sonic;
    BridgeTestLib.ChainConfig internal avalanche;

    constructor() {
        {
            uint forkSonic = vm.createFork(vm.envString("SONIC_RPC_URL"), SONIC_FORK_BLOCK);
            uint forkAvalanche = vm.createFork(vm.envString("AVALANCHE_RPC_URL"), AVALANCHE_FORK_BLOCK);

            sonic = BridgeTestLib.createConfigSonic(vm, forkSonic, TEST_DELEGATOR);
            avalanche = BridgeTestLib.createConfigAvalanche(vm, forkAvalanche, TEST_DELEGATOR);
        }

        BridgeTestLib.setUpSonicAvalanche(vm, sonic, avalanche);

        // ----------------------------- set up sonic
        vm.selectFork(sonic.fork);
        IHost hostSonic = IHost(IAuthority(sonic.authority).HOST());
        HostUtilsLib.setupHostInstance(vm, SonicConstantsLib.MULTISIG, IAuthority(sonic.authority), hostSonic);
        BridgeTestLib.setupHostBridgeAndHostFactory(vm, hostSonic, sonic, avalanche);

        // ----------------------------- set up avalanche
        vm.selectFork(avalanche.fork);
        IHost hostAvax = IHost(IAuthority(avalanche.authority).HOST());
        HostUtilsLib.setupHostInstance(vm, AvalancheConstantsLib.MULTISIG, IAuthority(avalanche.authority), hostAvax);
        BridgeTestLib.setupHostBridgeAndHostFactory(vm, hostAvax, avalanche, sonic);
    }

    //region ----------------------------------------- Tests

    /// @dev Bridge DAO in draft phase to another chain
    function testBridgeDao() public {
        // ------------------------ create dao on Sonic
        IDAOData.DaoData memory daoSonic = _createDao("ALIENS");

        IBridgedActions.BridgeDaoParams memory expectedParams = _bridgeDao(daoSonic);

        // ------------------------ Ensure that dao is correctly created on Avalanche
        vm.selectFork(avalanche.fork);
        IHost hostAvalanche = _getHostAvalanche();
        IDAOData.DaoData memory daoAvalanche = hostAvalanche.getDAO("ALIENS");

        assertEq(daoAvalanche.uid, daoSonic.uid, "dao uid");
        assertEq(daoAvalanche.symbol, daoSonic.symbol, "dao symbol");
        assertEq(daoAvalanche.name, daoSonic.name, "dao name");
        assertEq(daoAvalanche.params.ttBribe, daoSonic.params.ttBribe, "dao ttBribe");

        for (uint i; i < expectedParams.saltContractIndices.length; ++i) {
            bytes32 salt = hostAvalanche.salt(daoAvalanche.symbol, expectedParams.saltContractIndices[i]);
            assertEq(bytes32(salt), expectedParams.salts[i], string(abi.encodePacked("salt ", i)));
        }

        assertEq(daoAvalanche.unitIds.length, expectedParams.unitIds.length, "units");
        for (uint i; i < daoAvalanche.unitIds.length; i++) {
            assertEq(daoAvalanche.unitIds[i], expectedParams.unitIds[i], string(abi.encodePacked("unitId ", i)));
        }

        assertEq(
            keccak256(abi.encode(daoAvalanche.chainSettings)),
            keccak256(abi.encode(expectedParams.chainSettings)),
            "chainSettings"
        );
        assertEq(
            keccak256(abi.encode(daoAvalanche.params)),
            keccak256(abi.encode(expectedParams.daoParameters)),
            "dao params"
        );
    }

    function testBridgeDaoBadPaths() public {
        // ------------------------ create dao on Sonic
        IDAOData.DaoData memory dao = _createDao("ALIENS");

        vm.selectFork(sonic.fork);
        IHost hostSonic = _getHostSonic();

        // ------------------------ add units to dao
        _addUnitsToDao(hostSonic, dao.symbol);
        dao = hostSonic.getDAO(dao.symbol);

        // ------------------------ bridge dao from Sonic to Avalanche
        (uint32[] memory dstEids, IBridgedActions.BridgeDaoParams memory daoParams) = _prepareDataToBridgeDao(dao);

        // ------------------------ Error: no units
        {
            string[] memory correctUnits = daoParams.unitIds;
            daoParams.unitIds = new string[](0); // (!) no units

            bytes[] memory actionPayloads = new bytes[](1);
            IHostCodec codec = IHostCodec(sonic.hostCodec);
            actionPayloads[0] = codec.encode(daoParams, codec.PAYLOAD_API_VERSION());

            vm.expectRevert(IHost.UnitsRequired.selector);
            hostSonic.createBridgedAction(
                dao.symbol, uint16(IHost.BridgedActions.BRIDGE_DAO_1), dstEids, actionPayloads
            );

            daoParams.unitIds = correctUnits;
        }

        // ------------------------ Wrong symbol
        {
            string memory correctSymbol = daoParams.symbol;
            daoParams.symbol = "WRONG"; // (!) wrong symbol

            bytes[] memory actionPayloads = new bytes[](1);
            IHostCodec codec = IHostCodec(sonic.hostCodec);
            actionPayloads[0] = codec.encode(daoParams, codec.PAYLOAD_API_VERSION());

            vm.expectRevert(IHost.IncorrectInputData.selector);
            hostSonic.createBridgedAction(
                dao.symbol, uint16(IHost.BridgedActions.BRIDGE_DAO_1), dstEids, actionPayloads
            );

            daoParams.symbol = correctSymbol;
        }

        // ------------------------ Wrong name
        {
            string memory correctName = daoParams.name;
            daoParams.name = "WRONG"; // (!) wrong symbol

            bytes[] memory actionPayloads = new bytes[](1);
            IHostCodec codec = IHostCodec(sonic.hostCodec);
            actionPayloads[0] = codec.encode(daoParams, codec.PAYLOAD_API_VERSION());

            vm.expectRevert(IHost.IncorrectInputData.selector);
            hostSonic.createBridgedAction(
                dao.symbol, uint16(IHost.BridgedActions.BRIDGE_DAO_1), dstEids, actionPayloads
            );

            daoParams.name = correctName;
        }

        // ------------------------ Wrong phase

        // todo move to LIVE

        // todo try to bridge in LIVE phase => error
    }

    function testBridgeDaoParameters() public {
        vm.selectFork(sonic.fork);

        // ------------------------ create dao on Sonic
        IDAOData.DaoData memory dao = _createDao("ALIENS");
        _bridgeDao(dao);

        vm.selectFork(sonic.fork);
        IHost hostSonic = _getHostSonic();

        // ------------------------ bridge dao from Sonic to Avalanche
        (bytes memory proposalPayload, ITokenomics.DaoParameters memory daoParams) =
            _makeUpdateDaoParamsProposal(hostSonic, dao);

        // ------------------------ Process proposal on Sonic
        bytes32 proposalId = HostUtilsLib.getLastProposalId(hostSonic, dao.symbol);
        _processProposal(hostSonic, proposalId, proposalPayload);

        // ------------------------ Process bridged action on Avalanche
        vm.selectFork(avalanche.fork);
        assertNotEq(
            keccak256(abi.encode(_getHostAvalanche().getDAO(dao.symbol).params)),
            keccak256(abi.encode(daoParams)),
            "dao params are not updated"
        );

        _applyBridgeAction(dao, proposalId, proposalPayload, uint16(IHost.BridgedActions.SET_DAO_PARAMS_4));

        // ------------------------ Check results
        vm.selectFork(avalanche.fork);

        assertEq(
            keccak256(abi.encode(_getHostAvalanche().getDAO(dao.symbol).params)),
            keccak256(abi.encode(daoParams)),
            "dao params updated"
        );
    }

    function testBridgeDaoChainSettings() public {
        vm.selectFork(sonic.fork);

        // ------------------------ create dao on Sonic
        IDAOData.DaoData memory dao = _createDao("ALIENS");
        _bridgeDao(dao);

        vm.selectFork(sonic.fork);
        IHost hostSonic = _getHostSonic();

        // ------------------------ bridge dao from Sonic to Avalanche
        (bytes memory proposalPayload, ITokenomics.DaoChainSettings memory chainSettings) =
            _makeUpdateDaoChainSettingsProposal(hostSonic, dao);

        // ------------------------ Process proposal on Sonic
        bytes32 proposalId = HostUtilsLib.getLastProposalId(hostSonic, dao.symbol);
        _processProposal(hostSonic, proposalId, proposalPayload);

        // ------------------------ Process bridged action on Avalanche
        vm.selectFork(avalanche.fork);
        assertNotEq(
            keccak256(abi.encode(_getHostAvalanche().getDAO(dao.symbol).chainSettings)),
            keccak256(abi.encode(chainSettings)),
            "chain settings are not updated"
        );

        _applyBridgeAction(dao, proposalId, proposalPayload, uint16(IHost.BridgedActions.UPDATE_CHAIN_SETTINGS_6));

        // ------------------------ Check results
        vm.selectFork(avalanche.fork);

        assertEq(
            keccak256(abi.encode(_getHostAvalanche().getDAO(dao.symbol).chainSettings)),
            keccak256(abi.encode(chainSettings)),
            "chain settings updated"
        );
    }

    function testBridgeSetSalt() public {
        vm.selectFork(sonic.fork);

        // ------------------------ create dao on Sonic
        IDAOData.DaoData memory dao = _createDao("ALIENS");
        _bridgeDao(dao);

        vm.selectFork(sonic.fork);
        IHost hostSonic = _getHostSonic();

        // ------------------------ bridge dao from Sonic to Avalanche
        (bytes memory proposalPayload, uint16[] memory contractIndices, bytes32[] memory salt) =
            _makeSetSaltProposal(hostSonic, dao);

        // ------------------------ Process proposal on Sonic
        bytes32 proposalId = HostUtilsLib.getLastProposalId(hostSonic, dao.symbol);
        _processProposal(hostSonic, proposalId, proposalPayload);

        // ------------------------ Process bridged action on Avalanche
        vm.selectFork(avalanche.fork);
        IHost hostAvalanche = _getHostAvalanche();
        bytes32[] memory saltBefore = new bytes32[](contractIndices.length);
        for (uint i = 0; i < contractIndices.length; i++) {
            saltBefore[i] = hostAvalanche.salt(dao.symbol, contractIndices[i]);
        }

        _applyBridgeAction(dao, proposalId, proposalPayload, uint16(IHost.BridgedActions.SET_SALTS_5));

        vm.selectFork(avalanche.fork);
        bytes32[] memory saltAfter = new bytes32[](contractIndices.length);
        for (uint i = 0; i < contractIndices.length; i++) {
            saltAfter[i] = hostAvalanche.salt(dao.symbol, contractIndices[i]);
        }

        // ------------------------ Check results
        for (uint i = 0; i < contractIndices.length; i++) {
            assertEq(saltAfter[i], salt[i], string(abi.encodePacked("salt ", i)));
            assertNotEq(saltBefore[i], saltAfter[i], string(abi.encodePacked("salt changed ", i)));
        }
    }

    //endregion ----------------------------------------- Tests

    //region ----------------------------------------- Test logic
    function _bridgeDao(IDAOData.DaoData memory dao) internal returns (IBridgedActions.BridgeDaoParams memory) {
        vm.selectFork(sonic.fork);
        IHost hostSonic = _getHostSonic();

        // ------------------------ add units to dao
        _addUnitsToDao(hostSonic, dao.symbol);
        dao = hostSonic.getDAO(dao.symbol);

        // ------------------------ bridge dao from Sonic to Avalanche
        (bytes memory proposalPayload, IBridgedActions.BridgeDaoParams memory daoParams) =
            _makeBridgeDaoProposal(hostSonic, dao);

        // ------------------------ Process proposal on Sonic
        bytes32 proposalId = HostUtilsLib.getLastProposalId(hostSonic, dao.symbol);
        _processProposal(hostSonic, proposalId, proposalPayload);

        // ------------------------ Process bridged action on Avalanche
        _applyBridgeAction(dao, proposalId, proposalPayload, uint16(IHost.BridgedActions.BRIDGE_DAO_1));

        return daoParams;
    }

    function _getHostSonic() internal view returns (IHost) {
        return IHost(IAuthority(sonic.authority).HOST());
    }

    function _getHostAvalanche() internal view returns (IHost) {
        return IHost(IAuthority(avalanche.authority).HOST());
    }

    function _createDao(string memory symbol_) internal returns (IDAOData.DaoData memory dao) {
        // ----------------------------- create DAO on Sonic
        vm.selectFork(sonic.fork);
        vm.recordLogs();
        IHost host = _getHostSonic();
        _dealAndApprove(host);
        dao = HostUtilsLib.createAliensDao(vm, host, symbol_);

        // ------------------------- process cross chain events: Sonic -> Avalanche, Plasma
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _processCrossChainMessages(logs, sonic, avalanche);

        return dao;
    }

    function _addUnitsToDao(IHost host, string memory daoSymbol) internal {
        IDAOMetadata.UnitMetaData memory unitMetadata0 = IDAOMetadata.UnitMetaData({
            name: "DAO Factory",
            status: IDAOMetadata.UnitStatus.BUILDING_1,
            unitType: uint16(IDAOMetadata.UnitType.DEFI_PROTOCOL_1),
            revenueShare: 100,
            ui: new IDAOMetadata.UnitUiLink[](0),
            emoji: "",
            api: new string[](0)
        });

        IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](1);
        IDAOMetadata.UnitMetaData[] memory metas = new IDAOMetadata.UnitMetaData[](1);
        metas[0] = unitMetadata0;
        units[0] = IDAOData.UnitDataInput({unitId: "aliens:os", developerUid: ""});
        host.updateUnits(daoSymbol, units, metas);
    }

    function _processProposal(IHost host, bytes32 proposalId, bytes memory proposalPayload) internal {
        ITokenomics.Proposal memory proposal = host.proposal(proposalId);
        assertTrue(proposal.validationRequired, "proposal should require validation because of salts");
        assertTrue(proposal.votingRequired, "proposal should require voting");

        vm.prank(sonic.multisig);
        host.validateProposal(proposalId, true, proposalPayload);

        uint fee = host.quoteReceiveVotingResults(proposalId, true, proposalPayload);

        deal(sonic.multisig, fee);

        vm.recordLogs();

        vm.prank(sonic.multisig);
        host.receiveVotingResults{value: fee}(proposalId, true, proposalPayload);

        _processCrossChainMessages(vm.getRecordedLogs(), sonic, avalanche);
    }

    function _applyBridgeAction(
        IDAOData.DaoData memory dao,
        bytes32 proposalId,
        bytes memory proposalPayload,
        uint16 expectedActionKind
    ) internal {
        vm.selectFork(avalanche.fork);

        IHost hostAvalanche = _getHostAvalanche();

        assertTrue(hostAvalanche.isDaoSymbolInUse(dao.symbol), "dao symbol should be in use on Avalanche");
        // assertEq(hostAvalanche.getDAO(dao.symbol).uid, 0, "dao is not bridged");
        console.log("uid", hostAvalanche.getDAO(dao.symbol).uid, dao.uid);

        // get bridged action for Avalanche
        (,, bytes[] memory actionPayloads) = HostEncodingLib.decodeBridgedAction(proposalPayload);

        {
            (bool applied, uint16 actionKind, uint daoUid) =
                hostAvalanche.getBridgedAction(proposalId, actionPayloads[0]);
            assertEq(daoUid, dao.uid, "expected dao uid");
            assertFalse(applied, "not applied");
            assertEq(actionKind, expectedActionKind, "action kind");
        }

        vm.expectRevert(IHost.UnknownBridgedActionHash.selector);
        hostAvalanche.applyBridgedAction(bytes32(uint(proposalId) + 1), actionPayloads[0]);

        hostAvalanche.applyBridgedAction(proposalId, actionPayloads[0]);

        vm.expectRevert(IHost.BridgedActionAlreadyApplied.selector);
        hostAvalanche.applyBridgedAction(proposalId, actionPayloads[0]);

        {
            (bool applied, uint16 actionKind, uint daoUid) =
                hostAvalanche.getBridgedAction(proposalId, actionPayloads[0]);
            assertEq(daoUid, dao.uid, "expected dao uid");
            assertTrue(applied, "applied now");
            assertEq(actionKind, expectedActionKind, "action kind");
        }
    }

    //endregion  ----------------------------------------- Test logic

    //region  ----------------------------------------- Proposals logic
    function _makeBridgeDaoProposal(
        IHost host,
        IDAOData.DaoData memory dao
    ) internal returns (bytes memory proposalPayload, IBridgedActions.BridgeDaoParams memory daoParams) {
        uint32[] memory dstEids;
        (dstEids, daoParams) = _prepareDataToBridgeDao(dao);

        bytes[] memory actionPayloads = new bytes[](1);
        IHostCodec codec = IHostCodec(sonic.hostCodec);
        actionPayloads[0] = codec.encode(daoParams, codec.PAYLOAD_API_VERSION());

        vm.recordLogs();
        host.createBridgedAction(dao.symbol, uint16(IHost.BridgedActions.BRIDGE_DAO_1), dstEids, actionPayloads);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 payloadHash;
        (proposalPayload, payloadHash) = BridgeTestLib.extractProposalPayload(logs);
        assertEq(payloadHash, EfficientHashLib.hash(proposalPayload), "payload hash");
    }

    function _prepareDataToBridgeDao(
        IDAOData.DaoData memory dao
    ) internal view returns (uint32[] memory dstEids, IBridgedActions.BridgeDaoParams memory daoParams) {
        dstEids = new uint32[](1);
        dstEids[0] = avalanche.endpointId;

        string[] memory unitIds = new string[](dao.units.length);
        for (uint i = 0; i < dao.units.length; i++) {
            unitIds[i] = dao.units[i].unitId;
        }

        uint16[] memory saltContractIndices = new uint16[](1);
        saltContractIndices[0] = uint16(ITokenomicsAddons.ContractIndices.TOKEN_3);

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = "0x70859983";

        daoParams = IBridgedActions.BridgeDaoParams({
            symbol: dao.symbol,
            name: dao.name,
            unitIds: unitIds,
            chainSettings: dao.chainSettings,
            daoParameters: dao.params,
            saltContractIndices: saltContractIndices,
            salts: salts
        });
    }

    function _makeUpdateDaoParamsProposal(
        IHost host,
        IDAOData.DaoData memory dao
    ) internal returns (bytes memory proposalPayload, ITokenomics.DaoParameters memory daoParams) {
        uint32[] memory dstEids = new uint32[](1);
        dstEids[0] = avalanche.endpointId;

        daoParams = HostUtilsLib.generateDaoParams(333, 222);

        bytes[] memory actionPayloads = new bytes[](1);
        IHostCodec codec = IHostCodec(sonic.hostCodec);
        actionPayloads[0] = codec.encode(daoParams, codec.PAYLOAD_API_VERSION());

        vm.recordLogs();
        host.createBridgedAction(dao.symbol, uint16(IHost.BridgedActions.SET_DAO_PARAMS_4), dstEids, actionPayloads);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 payloadHash;
        (proposalPayload, payloadHash) = BridgeTestLib.extractProposalPayload(logs);
        assertEq(payloadHash, EfficientHashLib.hash(proposalPayload), "payload hash");
    }

    function _makeUpdateDaoChainSettingsProposal(
        IHost host,
        IDAOData.DaoData memory dao
    ) internal returns (bytes memory proposalPayload, ITokenomics.DaoChainSettings memory chainSettings) {
        uint32[] memory dstEids = new uint32[](1);
        dstEids[0] = avalanche.endpointId;

        chainSettings = ITokenomics.DaoChainSettings({bbRate: 65773219});

        bytes[] memory actionPayloads = new bytes[](1);
        IHostCodec codec = IHostCodec(sonic.hostCodec);
        actionPayloads[0] = codec.encode(chainSettings, codec.PAYLOAD_API_VERSION());

        vm.recordLogs();
        host.createBridgedAction(
            dao.symbol, uint16(IHost.BridgedActions.UPDATE_CHAIN_SETTINGS_6), dstEids, actionPayloads
        );

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 payloadHash;
        (proposalPayload, payloadHash) = BridgeTestLib.extractProposalPayload(logs);
        assertEq(payloadHash, EfficientHashLib.hash(proposalPayload), "payload hash");
    }

    function _makeSetSaltProposal(
        IHost host,
        IDAOData.DaoData memory dao
    ) internal returns (bytes memory proposalPayload, uint16[] memory contractIndices, bytes32[] memory salt) {
        uint32[] memory dstEids = new uint32[](1);
        dstEids[0] = avalanche.endpointId;

        contractIndices = new uint16[](2);
        contractIndices[0] = uint16(ITokenomicsAddons.ContractIndices.TOKEN_3);
        contractIndices[1] = uint16(ITokenomicsAddons.ContractIndices.SEED_TOKEN_1);

        salt = new bytes32[](2);
        salt[0] = "0x24310218";
        salt[1] = "0x24614082";

        bytes[] memory actionPayloads = new bytes[](1);
        IHostCodec codec = IHostCodec(sonic.hostCodec);
        actionPayloads[0] = codec.encode(contractIndices, salt, codec.PAYLOAD_API_VERSION());

        vm.recordLogs();
        host.createBridgedAction(dao.symbol, uint16(IHost.BridgedActions.SET_SALTS_5), dstEids, actionPayloads);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 payloadHash;
        (proposalPayload, payloadHash) = BridgeTestLib.extractProposalPayload(logs);
        assertEq(payloadHash, EfficientHashLib.hash(proposalPayload), "payload hash");
    }

    //endregion  ----------------------------------------- Proposals logic

    //region ----------------------------------------- Internal utils
    function _processCrossChainMessages(
        Vm.Log[] memory logs,
        BridgeTestLib.ChainConfig memory from,
        BridgeTestLib.ChainConfig memory to
    ) internal {
        vm.selectFork(to.fork);
        (bytes memory message,) = BridgeTestLib._extractSendMessage(logs);
        Origin memory origin =
            Origin({srcEid: from.endpointId, sender: bytes32(uint(uint160(address(from.hostBridge)))), nonce: 1});

        vm.prank(to.endpoint);
        IOAppReceiver(to.hostBridge)
            .lzReceive(
                origin,
                bytes32(0), // guid: actual value doesn't matter
                message,
                address(0), // executor
                "" // extraData
            );
    }

    /// @notice user should pay for DAO-creation
    function _dealAndApprove(IHost os_) internal {
        address exchangeAsset = os_.getChainSettings().exchangeAsset;
        uint amount = os_.getSettings().priceDao;
        deal(exchangeAsset, address(this), amount);
        IERC20(exchangeAsset).approve(address(os_), amount);
    }

    function _keepConsole() internal pure {
        console.log("keep console in imports");
    }
    //endregion ----------------------------------------- Internal utils
}
