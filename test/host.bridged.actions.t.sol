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
        IDAOData.DaoData memory dao = _createtDao("ALIENS");

        vm.selectFork(sonic.fork);
        IHost hostSonic = _getHostSonic();

        // ------------------------ add units to dao
        {
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
            hostSonic.updateUnits(dao.symbol, units, metas);

            dao = hostSonic.getDAO(dao.symbol);
        }

        // ------------------------ bridge dao
        bytes memory proposalPayload;
        {
            uint32[] memory dstEids = new uint32[](1);
            dstEids[0] = avalanche.endpointId;

            bytes[] memory actionPayloads = new bytes[](1);

            string[] memory unitIds = new string[](dao.units.length);
            for (uint i = 0; i < dao.units.length; i++) {
                unitIds[i] = dao.units[i].unitId;
            }

            uint16[] memory saltContractIndices = new uint16[](1);
            saltContractIndices[0] = uint16(ITokenomicsAddons.ContractIndices.TOKEN_3);

            bytes32[] memory salts = new bytes32[](1);
            salts[0] = "0x70859983";

            IHostCodec codec = IHostCodec(sonic.hostCodec);
            actionPayloads[0] = codec.encode(
                IBridgedActions.BridgeDaoParams({
                    symbol: dao.symbol,
                    name: dao.name,
                    unitIds: unitIds,
                    chainSettings: dao.chainSettings,
                    daoParameters: dao.params,
                    saltContractIndices: saltContractIndices,
                    salts: salts
                }),
                codec.PAYLOAD_API_VERSION()
            );

            vm.recordLogs();
            hostSonic.createBridgedAction(
                dao.symbol, uint16(IHost.BridgedActions.BRIDGE_DAO_1), dstEids, actionPayloads
            );

            Vm.Log[] memory logs = vm.getRecordedLogs();
            bytes32 payloadHash;
            (proposalPayload, payloadHash) = BridgeTestLib.extractProposalPayload(logs);
            assertEq(payloadHash, EfficientHashLib.hash(proposalPayload), "payload hash");
        }

        // ------------------------ Process proposal
        {
            bytes32 proposalId = HostUtilsLib.getLastProposalId(hostSonic, dao.symbol);
            ITokenomics.Proposal memory proposal = hostSonic.proposal(proposalId);
            assertTrue(proposal.validationRequired, "proposal should require validation because of salts");
            assertTrue(proposal.votingRequired, "proposal should require voting");

            vm.prank(sonic.multisig);
            hostSonic.validateProposal(proposalId, true, proposalPayload);

            uint fee = hostSonic.quoteReceiveVotingResults(proposalId, true, proposalPayload);

            deal(sonic.multisig, fee);

            vm.recordLogs();

            vm.prank(sonic.multisig);
            hostSonic.receiveVotingResults{value: fee}(proposalId, true, proposalPayload);

            _processCrossChainMessages(vm.getRecordedLogs(), sonic, avalanche);
        }

        // ------------------------ Process bridged action on Avalanche
        {
            vm.selectFork(avalanche.fork);

            IHost hostAvalanche = _getHostAvalanche();

            assertTrue(hostAvalanche.isDaoSymbolInUse(dao.symbol), "dao symbol should be in use on Avalanche");
            // assertEq(hostAvalanche.getDAO(dao.symbol).uid, 0, "dao is not bridged");
            console.log("uid", hostAvalanche.getDAO(dao.symbol).uid, dao.uid);

            // get bridged action for Avalanche
            (, , bytes[] memory actionPayloads) = HostEncodingLib.decodeBridgedAction(proposalPayload);

            {
                (bool applied, uint16 actionKind, uint daoUid) = hostAvalanche.getBridgedAction(EfficientHashLib.hash(actionPayloads[0]));
                assertEq(daoUid, dao.uid, "expected dao uid");
                assertFalse(applied, "not applied");
                assertEq(actionKind, uint16(IHost.BridgedActions.BRIDGE_DAO_1), "action kind");
            }

            hostAvalanche.applyBridgedAction(actionPayloads[0]);

            { // ----------------------- bad paths
                vm.expectRevert(IHost.BridgedActionAlreadyApplied.selector);
                hostAvalanche.applyBridgedAction(actionPayloads[0]);
            }

            {
                (bool applied, uint16 actionKind, uint daoUid) = hostAvalanche.getBridgedAction(EfficientHashLib.hash(actionPayloads[0]));
                assertEq(daoUid, dao.uid, "expected dao uid");
                assertTrue(applied, "applied now");
                assertEq(actionKind, uint16(IHost.BridgedActions.BRIDGE_DAO_1), "action kind");
            }

        }
    }

    //endregion ----------------------------------------- Tests

    //region ----------------------------------------- Test logic
    function _getHostSonic() internal view returns (IHost) {
        return IHost(IAuthority(sonic.authority).HOST());
    }

    function _getHostAvalanche() internal view returns (IHost) {
        return IHost(IAuthority(avalanche.authority).HOST());
    }

    function _createtDao(string memory symbol_) internal returns (IDAOData.DaoData memory dao) {
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

    //endregion  ----------------------------------------- Test logic

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
