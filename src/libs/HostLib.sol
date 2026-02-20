// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EfficientHashLib} from "@solady/utils/EfficientHashLib.sol";

/// @notice Basic data types and constants for Host system. This library shouldn't depend on any other libraries.
library HostLib {
    // keccak256(abi.encode(uint(keccak256("erc7201:stability.host-contracts.Host")) - 1)) & ~bytes32(uint(0xff));
    bytes32 public constant HOST_STORAGE_LOCATION = 0x361148703eaf4fc488297f0e16b0f65ec74281fb03e045d7f0f5434276acc900;

    /// @notice Predefined UID of the unit of host DAO. This unit is used to collect dao-creation fees
    string public constant HOST_UNIT = "host-unit";

    /// @notice Values in range [0..99) are reserved for internal use (so we can use some values as stubs)
    uint private constant MIN_DAO_UID = 100;

    /// @dev Decimals for percents
    uint public constant DENOMINATOR = 100_000;

    /// @notice This value is used in daoUids mapping to mark that the given symbol is registered
    /// @dev We don't know exact daoUid at the moment of registration at segment 1, we only know that the symbol is in use
    uint internal constant DAO_UID_STUB_SYMBOL_REGISTERED = 1;

    //region -------------------------------------- Data types
    /// @notice ON-CHAIN on chains where DAO bridged (some additional structs are stored in separate mappings)
    struct DaoDataSegment2 {
        /// @notice Symbol is stored here to have a mapping: daoUid => symbol
        string symbol;

        /// @notice Name of the DAO, used in token names. Without DAO word.
        string name;

        /// @notice DAO lifecycle phase. Changes permissionless when next phase start timestamp reached.
        /// @dev This value is updated on bridged chains only after passing LIVE_CLIFF_5
        IDAOData.LifecyclePhase phase;

        /// @notice Ids of all units registered in the DAO.
        /// @dev Different DAO can use same unit ids, but Hash = hash of (daoUid, unitUid) is unique.
        string[] unitIds;
    }

    /// @notice ON-CHAIN on initial chain of DAO (some additional structs are stored in separate mappings)
    struct DaoDataSegment3 {
        /// @notice id of the chain where initial deployment became
        uint initialChain;

        /// @notice Community socials. Update by `OS.updateSocials`
        string[] socials;

        /// @notice List of activities of the DAO
        IDAOData.Activity[] activity;

        /// @notice Fundraising. Only funding types.
        /// @dev Actual funding data are stored in the mapping (to be able to extend list of Funding fields)
        IDAOData.FundingType[] funding;

        /// @notice Vesting allocations (optional — may be empty). Count of registered vesting items.
        /// @dev Actual vesting data are stored in the mapping (to be able to extend list of Vesting fields)
        uint countVesting;

        /// @notice Deployer of a DAO have power only at DRAFT phase.
        address deployer;

        /// @notice DAO custom metadata stored off-chain
        string daoMetaDataLocation;
    }

    /// @notice All "small" fields of the proposal. We store them packed as a single slot.
    struct ProposalHeader {
        /// @dev Action to update DAO data
        IDAOData.DAOAction action;

        /// @dev True if proposal requires validation by Host DAO before voting
        /// Typical rejection case: proposal contains invalid data that have collisions with exist data on other chains
        /// I.e. proposed salt is already used on the target chain
        bool validationRequired;

        /// @dev True if proposal requires voting. Some kind of proposals cannot be instant because they require validation
        bool votingRequired;

        /// @dev Status of proposal validation by admin
        IDAOData.ValidationStatus validationStatus;

        /// @dev Current voting status
        IDAOData.VotingStatus status;

        /// @notice Proposal creation timestamp
        uint64 created;
    }

    /// @notice It refers to daoUid instead of symbol
    struct ProposalData {
        /// @notice ProposalHeader packed to single slot
        uint proposalHeader;

        /// @notice Unique proposal id
        bytes32 id;

        /// @notice DAO UID
        uint daoUid;

        // payload is NOT stored on chain, we store only hash and emit event with payload
        //        /// @notice Proposal data as bytes. Actual data depends on {action}
        //        bytes payload;

        /// @notice Hash of proposal payload
        bytes32 payloadHash;
    }

    /// @notice Unit data stored in the storage
    struct UnitLocal {
        uint daoUid;

        /// @notice Unique unit string id. For DeFi protocol its defiOrg:protocolKey.
        string unitId;

        /// @notice DAO UID of Unit Developer (Pool tasks solver)
        string developerUid;

        /// @notice Set of chain ids where the unit is bridged
        EnumerableSet.UintSet chainIds;
    }

    struct BridgedActionHeader {
        uint16 actionKind;
        bool applied;
    }

    /// @dev Bridged action registered on the initial chain and transferred to other chains via cross-chain messages
    struct BridgedActionLocal {
        /// @dev Packed bridged action data
        uint bridgedActionHeader;
        uint daoUid;
    }

    /// @custom:storage-location erc7201:stability.host-contracts.Host
    struct HostStorage {
        /// @notice Internal counter of created DAOs. It's used to generate unique immutable id for each DAO.
        /// @dev The counter is started from MIN_DAO_UID. ALl values in the range [0...MIN_DAO_UID) are reserved for internal use.
        uint daoCounter;

        /// @notice UID of the host DAO
        uint hostDaoUid;

        // todo probably it's more safe to add all data at the end always
        uint[50] __gap;

        // -------------------------------------- SEGMENT 1: ALl chains with Host deployed
        /// @notice Mapping from DAO symbol (changeable) to its unique id
        /// @dev This mapping is used to store:
        ///    symbol => DAO_UID_STUB_SYMBOL_REGISTERED (segment 1: the symbol is in use but it's daoUid is not known)
        ///    symbol => daoUid (segment 2: actual uid of the dao with the given symbol is stored)
        mapping(string symbol => uint daoUid) daoUids;

        /// @notice All bridged actions received from other chains. Key is hash of action payload.
        mapping(bytes32 actionHash => BridgedActionLocal) bridgedActionHashes;

        // -------------------------------------- SEGMENT 2: All chains where DAO is bridged

        /// @notice Data of each DAO deployed or bridged to the current chain
        mapping(uint daoUid => DaoDataSegment2) segment2;

        /// @notice All deployments of DAOs on different chains. Deployment ID is generated as hash of (daoUid, chainId)
        mapping(uint daoUid => IDAOData.DaoDeploymentInfo) deployments;

        /// @notice Settings of DAO for current chain. This is the only place to save settings of DAO for chains.
        mapping(uint daoUid => IDAOData.DaoChainSettings) chainSettings;

        /// @notice Parameters of each DAO
        mapping(uint daoUid => IDAOData.DaoParameters) daoParameters;

        /// @notice Balances of assets belonging to the given unit. Key is generated as hash of (daoUid, unitUid)
        mapping(bytes32 hashUnit => EnumerableMap.AddressToUintMap) unitBalances;

        /// @notice Salt configured for DAO contracts.
        /// @dev Key is generated as hash of (daoUid, ContractIndex)
        /// @dev ContractIndex is specified by enum IDAODataAddons.ContractIndices, HostLib.getKey
        mapping(bytes32 key => bytes32 salt) salt;

        /// @notice The mapping allows to check if the given salt is already used by some DAO on the given chain
        mapping(bytes32 salt => uint daoUid) daoUidBySalt;

        /// @notice List of whitelisted assets on the current chain. Revenue can be registered for units in whitelisted assets only.
        mapping(address asset => bool) whitelistedAssets;

        // todo probably it's more safe to add all data at the end always
        uint[50] __gap_segment2;

        // -------------------------------------- SEGMENT 3: Initial chain only
        /// @notice Data of each DAO deployed to the current chain
        mapping(uint daoUid => DaoDataSegment3) segment3;

        /// @notice Images (logo/banner) of each DAO
        mapping(uint daoUid => IDAOData.DaoImages) daoImages;

        /// @notice Revenue generating units owned by the organization. Key is generated as hash of (daoUid, unitUid)
        mapping(bytes32 hashUnit => UnitLocal) units;

        /// @notice Fundraising. FundingId is generated as hash of (daoUid, funding type)
        mapping(bytes32 fundingId => IDAOData.Funding) funding;

        /// @notice Vesting allocations. Key is generated as hash of (daoUid, 0-index)
        mapping(bytes32 key => IDAOData.Vesting) vesting;

        /// @notice Settings of DAO Governance
        mapping(uint daoUid => IDAOData.GovernanceSettings) governanceSettings;

        // todo probably it's more safe to add all data at the end always
        uint[50] __gap_segment3;

        // -------------------------------------- Proposals
        /// @notice All registered proposals. Proposal id is unique across all DAOs
        mapping(bytes32 proposalId => ProposalData) proposals;

        /// @notice List of ids of all proposals for each DAO in order
        mapping(uint daoUid => bytes32[] proposalIds) daoProposals;
    }

    //endregion -------------------------------------- Data types

    //region -------------------------------------- Internal utils
    function getHostStorage() internal pure returns (HostStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := HOST_STORAGE_LOCATION
        }
    }

    function setupDaoCounter() internal {
        HostStorage storage $ = getHostStorage();
        if ($.daoCounter < MIN_DAO_UID) {
            $.daoCounter = MIN_DAO_UID;
        }
    }

    /// @notice Generate hash of (daoUid + index in the array)
    /// @param daoUid Unique immutable id of the DAO
    /// @param index 0-based index in the array
    function getIndexKey(uint daoUid, uint index) internal pure returns (bytes32) {
        return EfficientHashLib.hash(daoUid, index);
    }

    function getKey(uint daoUid, uint value) internal pure returns (bytes32) {
        return EfficientHashLib.hash(daoUid, value);
    }

    function getKey(uint daoUid, uint value1, uint value2) internal pure returns (bytes32) {
        return EfficientHashLib.hash(daoUid, value1, value2);
    }

    function getUnitKey(uint daoUid, string memory unitId) internal pure returns (bytes32) {
        return keccak256(abi.encode(daoUid, unitId));
    }

    /// @notice All DAO have unique symbol but it can be changed. We need immutable unique id for various internal processes.
    /// @return uid New unique immutable id of the created DAO
    /// @return firstDao True if it's the first DAO ever created in the system
    function generateDaoUid(HostLib.HostStorage storage $) internal returns (uint uid, bool firstDao) {
        uint count = $.daoCounter + 1;
        $.daoCounter = count;
        return (generateDaoUid(count, block.chainid), count == MIN_DAO_UID + 1);
    }

    /// @notice Generate hash of (daoUid, kind)
    /// @param daoUid Unique immutable id of the DAO
    /// @param kind Kind of the hash (0 - used, 1 - reserved salt)
    function getDaoHash(uint daoUid, uint kind) internal pure returns (uint) {
        return uint(EfficientHashLib.hash(daoUid, kind));
    }

    /// @notice This value is used in daoUids mapping to mark that the given symbol is registered
    function getDaoUidStub() internal view returns (uint) {
        return generateDaoUid(DAO_UID_STUB_SYMBOL_REGISTERED, block.chainid);
    }

    /// @notice Calculate DAO id, it's unique for all chains
    function generateDaoUid(uint count_, uint chain_) internal pure returns (uint) {
        //return uint(keccak256(abi.encodePacked(count_, chain_)));
        return uint(EfficientHashLib.hash(count_, chain_));
    }

    /// @notice Get value of dao uid. Returns 0 for stub values
    function getDaoUid(HostLib.HostStorage storage $, string memory symbol) internal view returns (uint daoUid) {
        daoUid = $.daoUids[symbol];
        return daoUid == getDaoUidStub() ? 0 : daoUid;
    }

    //endregion -------------------------------------- Internal utils

    //region -------------------------------------- Pack/unpack
    /// @notice Pack ProposalHeader into single uint
    function packProposalHeader(ProposalHeader memory header) internal pure returns (uint h) {
        h = uint(uint8(header.action)) | (header.validationRequired ? (1 << 8) : 0)
            | (header.votingRequired ? (1 << 9) : 0) | (uint(uint8(header.validationStatus)) << 10)
            | (uint(uint8(header.status)) << 18) | (uint(header.created) << 26);
    }

    /// @notice Unpack ProposalHeader from single uint
    function unpackProposalHeader(uint h) internal pure returns (ProposalHeader memory header) {
        return ProposalHeader({
            action: IDAOData.DAOAction(uint8(h)),
            validationRequired: ((h >> 8) & 1) != 0,
            votingRequired: ((h >> 9) & 1) != 0,
            validationStatus: IDAOData.ValidationStatus(uint8(h >> 10)),
            status: IDAOData.VotingStatus(uint8(h >> 18)),
            created: uint64(h >> 26)
        });
    }

    function packBridgedActionHeader(BridgedActionHeader memory header) internal pure returns (uint h) {
        h = uint(uint16(header.actionKind)) | (header.applied ? (1 << 16) : 0);
    }

    function unpackBridgedActionHeader(uint h) internal pure returns (BridgedActionHeader memory header) {
        header.actionKind = uint16(h & 0xFFFF);
        header.applied = ((h >> 16) & 1) != 0;
    }

    //endregion -------------------------------------- Pack/unpack
}
