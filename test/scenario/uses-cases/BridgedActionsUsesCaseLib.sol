// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EngineLib} from "../engine/EngineLib.sol";
import {Vm} from "forge-std/Test.sol";
import {EventUtilsLib} from "../../utils/EventUtilsLib.sol";
import {HostUtilsLib} from "../../utils/HostUtilsLib.sol";
import {IBridgedActions} from "../../../src/interfaces/IBridgedActions.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";
import {BridgeTestLib} from "../../utils/BridgeTestLib.sol";

library BridgedActionsUsesCaseLib {
    function bridgeDao(
        Vm vm,
        string memory user,
        string memory symbol,
        EngineLib.ChainConfig memory src,
        EngineLib.ChainConfig memory target,
        IBridgedActions.BridgeDaoParams memory data
    ) internal {

        bytes memory proposalPayload;

        // ----------------- 1. User registers BRIDGE_DAO_1 action on chain 1
        {
            uint32[] memory dstEids = new uint32[](1);
            dstEids[0] = uint32(target.chainId);

            bytes[] memory actionPayloads = new bytes[](1);
            actionPayloads[0] = src.hostCodec.encode(data, src.hostCodec.PAYLOAD_API_VERSION());

            vm.selectFork(src.fork);

            // ---------------------- Create proposal to bridge dao on chain 2
            vm.recordLogs();
            src.host.createBridgedAction(
                symbol,
                uint16(IHost.BridgedActions.BRIDGE_DAO_1),
                dstEids,
                actionPayloads
            );

            // ---------------------- Receive emitted proposal payload
            Vm.Log[] memory logs = vm.getRecordedLogs();
            (proposalPayload, ) = EventUtilsLib.extractProposalPayloadAndHash(logs);
        }

        // ----------------- 2. Proposal is validated and voted successfully on chain 1
        bytes32 proposalId;
        {
            proposalId = HostUtilsLib.getLastProposalId(src.host, symbol);
            IDAOData.Proposal memory proposal = IDataReader(src.host.getChainSettings().dataReader).proposal(proposalId);

            if (proposal.validationRequired) {
                uint fee = src.host.quoteProposalAction(proposalId, proposalPayload, IHost.ValidationMethod.VALIDATION_1);

                vm.prank(src.hostValidator);
                src.host.validateProposal{value: fee}(proposalId, true, proposalPayload);
            }

            if (proposal.votingRequired) {
                uint fee = src.host.quoteProposalAction(proposalId, proposalPayload, IHost.ValidationMethod.VOTING_0);

                vm.recordLogs();

                vm.prank(src.hostValidator);
                src.host.receiveVotingResults{value: fee}(proposalId, true, proposalPayload);

                BridgeTestLib.processCrossChainMessages(vm, vm.getRecordedLogs(), src, target);
            }
        }

        // ----------------- 2. User applies registered action on chain 2
        vm.selectFork(target.fork);

        target.host.applyBridgedAction(proposalId, proposalPayload);
    }

}