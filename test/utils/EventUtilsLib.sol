// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Test.sol";

library EventUtilsLib {
    function extractProposalPayload(Vm.Log[] memory logs) internal pure returns (bytes memory payload) {
        bytes32 sig = keccak256("Proposal(uint256,uint8,bytes32,bytes32,bytes)");

        for (uint i; i < logs.length; ++i) {
            if (logs[i].topics[0] == sig) {
                (,,,, payload) = abi.decode(logs[i].data, (uint, uint8, bytes32, bytes32, bytes));
                break;
            }
        }

        return payload;
    }

    function extractProposalPayloadAndHash(Vm
                .Log[] memory logs) internal pure returns (bytes memory payload, bytes32 payloadHash) {
        // extract event Proposal(uint daoUid, IDAOData.DAOAction action, bytes32 proposalId, bytes32 payloadHash, bytes payload);
        bytes32 sig = keccak256("Proposal(uint256,uint8,bytes32,bytes32,bytes)");

        for (uint i; i < logs.length; ++i) {
            if (logs[i].topics[0] == sig) {
                (,,, payloadHash, payload) = abi.decode(logs[i].data, (uint, uint8, bytes32, bytes32, bytes));
                break;
            }
        }

        return (payload, payloadHash);
    }

    function extractDeployedProxy(Vm.Log[] memory entries) internal pure returns (address deployedProxy) {
        // Only support ProxyCreated(address) event: proxy is indexed (topics[1])
        bytes32 sigCreated = keccak256("ProxyCreated(address)");

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics.length != 0 && entries[i].topics[0] == sigCreated) {
                // ProxyCreated has indexed proxy => topics[1] contains the address
                if (entries[i].topics.length > 1) {
                    deployedProxy = address(uint160(uint(entries[i].topics[1])));
                } else {
                    // fallback: decode from data if not indexed for some reason
                    deployedProxy = abi.decode(entries[i].data, (address));
                }
                break;
            }
        }
        return deployedProxy;
    }
}
