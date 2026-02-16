// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

//import {console} from "forge-std/console.sol";
import {EfficientHashLib} from "@solady/utils/EfficientHashLib.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {HostEncodingLib} from "./HostEncodingLib.sol";
import {HostCrossChainLib} from "./HostCrossChainLib.sol";
import {HostLib} from "./HostLib.sol";
import {HostConfigLib} from "./HostConfigLib.sol";
import {IHost} from "../interfaces/IHost.sol";
import {IDAOData} from "../interfaces/IDAOData.sol";
import {ITokenomics} from "../interfaces/ITokenomics.sol";

/// @notice Data validation, updating logic
library HostUpdateLib {
    using EnumerableSet for EnumerableSet.UintSet;

    //region -------------------------------------- Actions
    function validate(
        uint daoUid,
        ITokenomics.LifecyclePhase phase,
        HostLib.DaoDataSegment2 memory daoData2,
        ITokenomics.DaoParameters memory params,
        ITokenomics.Funding[] memory funding,
        ITokenomics.Activity[] memory activity
    ) internal view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        _validateDaoData(daoData2, st);
        _validateDaoParameters(daoUid, phase, params, st);
        _validateFundingList(funding, st);
        _validateActivity(activity);
    }

    //endregion -------------------------------------- Actions

    //region -------------------------------------- Validation logic

    /// @notice Ensure that DAO name is in the range [minNameLength, maxNameLength]
    function _validateDaoData(HostLib.DaoDataSegment2 memory dao, IHost.HostSettings storage st) internal view {
        _validateNaming(dao.name, dao.symbol, st);
    }

    /// @dev activity contains only valid enum values - decoder reverts automatically if it contains invalid value
    function _validateActivity(ITokenomics.Activity[] memory activity) internal pure {
        uint count = uint(ITokenomics.Activity.COUNT_ACTIVITY);
        bool[] memory foundActivity = new bool[](count);

        uint len = activity.length;
        for (uint i; i < len; ++i) {
            /// @dev Check that activity are not repeat
            require(!foundActivity[uint(activity[i])], IHost.InvalidActivityCombination());
            foundActivity[uint(activity[i])] = true;
        }

        require(
            len > 1 || !foundActivity[uint(ITokenomics.Activity.BUILDER_3)], IHost.SingleBuilderActivityNotAllowed()
        );
    }

    /// @dev Check length of name and symbol, uppercase requirement for symbol and uniqueness of symbol
    function _validateNaming(string memory name, string memory symbol, IHost.HostSettings storage st) internal view {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        {
            uint len = bytes(name).length;
            require(len >= st.minNameLength && len <= st.maxNameLength, IHost.NameLength(len));
        }

        {
            uint len = bytes(symbol).length;
            require(len >= st.minSymbolLength && len <= st.maxSymbolLength, IHost.SymbolLength(len));

            // @dev Symbol must be uppercase only
            require(
                EfficientHashLib.hash(abi.encode(LibString.upper(symbol))) == EfficientHashLib.hash(abi.encode(symbol)),
                IHost.UpperCaseRequired(symbol)
            );

            require(HostLib.getDaoUid($, symbol) == 0, IHost.SymbolNotUnique(symbol));
        }
    }

    /// @notice Validate DAO params according to OS settings
    function _validateDaoParameters(
        uint daoUid,
        ITokenomics.LifecyclePhase phase,
        ITokenomics.DaoParameters memory params,
        IHost.HostSettings storage st
    ) internal view {
        require(params.pvpFee >= st.minPvPFee && params.pvpFee <= st.maxPvPFee, IHost.PvPFee(params.pvpFee));
        require(params.vePeriod >= st.minVePeriod && params.vePeriod <= st.maxVePeriod, IHost.VePeriod(params.vePeriod));
        if (phase >= ITokenomics.LifecyclePhase.TGE_5) {
            require(
                params.totalSupply == HostLib.getHostStorage().daoParameters[daoUid].totalSupply,
                IHost.TooLateToUpdateTotalSupply()
            );
        }
    }

    function _validateDaoChainSettings(ITokenomics.DaoChainSettings memory settings) internal pure {
        require(settings.bbRate <= 100, IHost.TooHighValue());
    }

    /// @notice Check funding list before creation
    function _validateFundingList(ITokenomics.Funding[] memory funding, IHost.HostSettings storage st) internal view {
        require(funding.length != 0, IHost.NeedFunding());

        bool[] memory foundFunding = new bool[](uint(ITokenomics.FundingType.COUNT_FUNDING_TYPES));
        uint len = funding.length;
        for (uint i; i < len; ++i) {
            require(!foundFunding[uint(funding[i].fundingType)], IHost.InvalidFundingArray());
            foundFunding[uint(funding[i].fundingType)] = true;

            _validateFunding(funding[i], st);
        }
    }

    /// @dev Check funding params according to Host settings
    function _validateFunding(ITokenomics.Funding memory funding, IHost.HostSettings storage st) internal view {
        uint duration = funding.end > funding.start ? funding.end - funding.start : 0;
        require(duration >= st.minFundingDuration && duration <= st.maxFundingDuration, IHost.InvalidFundingPeriod());

        require(
            funding.maxRaise > funding.minRaise && funding.maxRaise <= st.maxFundingRaise
                && funding.minRaise >= st.minFundingRaise,
            IHost.InvalidFundingRaise()
        );
    }

    /// @dev Check funding before updating. Funding can be updated on proper phase only.
    function _validateFunding(
        ITokenomics.LifecyclePhase phase,
        ITokenomics.Funding memory funding,
        IHost.HostSettings storage st
    ) internal view {
        if (funding.fundingType == ITokenomics.FundingType.SEED_0) {
            require(
                phase == ITokenomics.LifecyclePhase.DRAFT_0 || phase == ITokenomics.LifecyclePhase.INCEPTION_1,
                IHost.TooLateToUpdateSuchFunding()
            );
        }

        if (funding.fundingType == ITokenomics.FundingType.TGE_1) {
            require(
                phase == ITokenomics.LifecyclePhase.DRAFT_0 || phase == ITokenomics.LifecyclePhase.INCEPTION_1
                    || phase == ITokenomics.LifecyclePhase.SEED_2 || phase == ITokenomics.LifecyclePhase.DEVELOPMENT_4,
                IHost.TooLateToUpdateSuchFunding()
            );
        }

        _validateFunding(funding, st);
    }

    /// @param tgeClaim Date of DAO launching (after TGE finishing, DAO token is deployed, etc)
    function _validateVestingList(
        ITokenomics.LifecyclePhase phase,
        ITokenomics.Vesting[] memory vesting,
        IHost.HostSettings storage st,
        uint tgeClaim
    ) internal view {
        require(
            phase != ITokenomics.LifecyclePhase.LIVE_CLIFF_6 && phase != ITokenomics.LifecyclePhase.LIVE_VESTING_7
                && phase != ITokenomics.LifecyclePhase.LIVE_8,
            IHost.TooLateToUpdateVesting()
        );

        uint len = vesting.length;
        require(tgeClaim != 0 || len == 0, IHost.VestingNotAllowed());

        uint totalAllocation;
        for (uint i; i < len; ++i) {
            _validateVesting(vesting[i], st, tgeClaim);
            totalAllocation += vesting[i].allocation;
        }

        require(totalAllocation < 100_000, IHost.TotalAllocationTooHigh());
    }

    function _validateVesting(
        ITokenomics.Vesting memory vesting,
        IHost.HostSettings storage st,
        uint claim
    ) internal view {
        {
            uint len = bytes(vesting.name).length;
            require(len >= st.minVestingNameLen && len <= st.maxVestingNameLen, IHost.NameLength(len));
        }

        require(vesting.allocation != 0, IHost.ZeroValueNotAllowed());

        require(vesting.start >= claim + st.minCliff, IHost.IncorrectVestingStart());
    }

    /// @notice Validate salts: salts is not used OR used by the given DAO
    function _validateSalt(uint daoUid, uint16[] memory contractIndices, bytes32[] memory salt_) internal view {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        uint len = contractIndices.length;
        require(len != 0 && len == salt_.length, IHost.IncorrectArrayLengths());

        for (uint i; i < len; ++i) {
            require(
                contractIndices[i] < uint16(ITokenomics.ContractIndices.COUNT_CONTRACT_INDICES),
                IHost.TooHighContractIndex(contractIndices[i])
            );

            // assume that users don't try to set same salt for different contracts
            // otherwise they will have error on creation (and will be able to fix it)
            uint saltDaoUid = $.daoUidBySalt[salt_[i]];
            require(saltDaoUid == 0 || saltDaoUid == daoUid, IHost.SaltAlreadyUsed(salt_[i]));
        }
    }

    //endregion -------------------------------------- Validation logic

    //region -------------------------------------- Update logic

    /// @notice Update images (logo/banner) of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.DaoImages struct
    function updateImages(uint daoUid, bytes memory payload) internal {
        ITokenomics.DaoImages memory images = HostEncodingLib.decodeDaoImages(payload);
        updateImages(daoUid, images);
    }

    function updateImages(uint daoUid, ITokenomics.DaoImages memory images) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoImages[daoUid] = images;
        emit IHost.DaoImagesUpdated($.segment2[daoUid].symbol, images);
    }

    /// @notice Update socials of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded string[] array
    function updateSocials(uint daoUid, bytes memory payload) internal {
        string[] memory socials = HostEncodingLib.decodeSocials(payload);
        updateSocials(daoUid, socials);
    }

    function updateSocials(uint daoUid, string[] memory socials) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment3[daoUid].socials = socials;
        emit IHost.DaoSocialsUpdated($.segment2[daoUid].symbol, socials);
    }

    /// @notice Update revenue generating units of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.UnitInfo[] array
    /// @param proposalId Id of the proposal that triggered this update. Not zero here
    function updateUnitsForProposal(uint daoUid, bytes memory payload, bytes32 proposalId) internal {
        IDAOData.UnitDataInput[] memory units = HostEncodingLib.decodeUnits(payload);

        /// @dev Empty array required by updateUnits. It's not used because proposalId is not zero here
        IDAOData.UnitEmitData[] memory metadata;

        updateUnits(daoUid, units, proposalId, metadata);
    }

    /// @param proposalId Id of the proposal that triggered this update. Zero for instant execution
    /// @param metadata List of metadata - for instant updates only
    function updateUnits(
        uint daoUid,
        IDAOData.UnitDataInput[] memory units,
        bytes32 proposalId,
        IDAOData.UnitEmitData[] memory metadata
    ) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        // todo take prices for unit creation

        /// @dev False - insert, true - update
        bool[] memory updates = new bool[](units.length);

        /// @dev Hashes for new units
        bytes32[] memory newHashes = new bytes32[](units.length);

        /// @dev Ids of new units
        string[] memory newUnitIds = new string[](units.length);

        {
            // -------------------- detect units to update/insert and units to delete
            /// @dev Ids of exist units
            string[] memory existUnitIds = $.segment2[daoUid].unitIds;

            /// @dev Hashes of exist units
            bytes32[] memory existHashes = new bytes32[](existUnitIds.length);
            for (uint i; i < existUnitIds.length; ++i) {
                existHashes[i] = HostLib.getUnitKey(daoUid, existUnitIds[i]);
            }

            /// @dev Marks hashes that exist both in unitIdsExist and newUnitIds and so should be kept
            bool[] memory notDelete = new bool[](existHashes.length);

            for (uint i; i < newUnitIds.length; ++i) {
                newUnitIds[i] = units[i].unitId;
                newHashes[i] = HostLib.getUnitKey(daoUid, newUnitIds[i]);

                for (uint j; j < existHashes.length; ++j) {
                    if (existHashes[j] == newHashes[i]) {
                        // new unit exist in list of exist units, don't delete it
                        notDelete[j] = true;
                        updates[i] = true;
                        break;
                    }
                }
            }

            // -------------------- delete old units (the units that don't exist in {units} list anymore}
            for (uint j; j < existHashes.length; ++j) {
                if (!notDelete[j]) {
                    emit IHost.DaoUnitDeleted(daoUid, existUnitIds[j], proposalId);
                    // todo probably we shouldn't call delete to reduce gas costs (?)
                    delete $.units[existHashes[j]];
                }
            }
        }

        // -------------------- insert and update new units

        $.segment2[daoUid].unitIds = newUnitIds;

        for (uint i; i < newHashes.length; i++) {
            HostLib.UnitLocal storage unit = $.units[newHashes[i]];
            if (updates[i]) {
                // update existing unit
                unit.developerUid = units[i].developerUid;
            } else {
                // todo move code below to a separate function
                // insert new unit
                unit.daoUid = daoUid;
                unit.unitId = units[i].unitId;
                unit.developerUid = units[i].developerUid;
                unit.chainIds.add(block.chainid);
            }

            if (proposalId == 0) {
                emit IHost.DaoUnitUpdatedInstantly(daoUid, units[i].unitId, metadata[i]);
            } else {
                // we don't need to emit metadata here because it's emitted during proposal creation
                emit IHost.DaoUnitUpdatedByProposal(daoUid, units[i].unitId, proposalId);
            }
        }
    }

    /// @notice Replace array of funding of the DAO by new one
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.Funding[] array
    function updateFunding(uint daoUid, bytes memory payload) internal {
        ITokenomics.Funding memory newFunding = HostEncodingLib.decodeFunding(payload);
        updateFunding(daoUid, newFunding);
    }

    function updateFunding(uint daoUid, ITokenomics.Funding memory newFunding) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.FundingType[] memory listFunding = $.segment3[daoUid].funding;

        // slither-disable-next-line uninitialized-local
        bool updated;

        for (uint i; i < listFunding.length; i++) {
            if (listFunding[i] == newFunding.fundingType) {
                updated = true;
                break;
            }
        }
        if (!updated) {
            $.segment3[daoUid].funding.push(newFunding.fundingType);
        }

        bytes32 fundingId = HostLib.getKey(daoUid, uint(newFunding.fundingType));
        $.funding[fundingId] = newFunding;

        emit IHost.DaoFundingUpdated(daoUid, newFunding);
    }

    /// @notice Update vesting allocations of the DAO
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.Vesting[] array
    function updateVesting(uint daoUid, bytes memory payload) internal {
        ITokenomics.Vesting[] memory vesting = HostEncodingLib.decodeVesting(payload);
        updateVesting(daoUid, vesting);
    }

    function updateVesting(uint daoUid, ITokenomics.Vesting[] memory vesting) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        uint countVesting = vesting.length;
        $.segment3[daoUid].countVesting = countVesting;

        for (uint i = 0; i < countVesting; i++) {
            bytes32 key = HostLib.getIndexKey(daoUid, i);
            $.vesting[key] = HostLib.VestingLocal({
                name: vesting[i].name, allocation: vesting[i].allocation, start: vesting[i].start, end: vesting[i].end
            });
        }

        emit IHost.DaoVestingUpdated(daoUid, vesting);
    }

    /// @notice Update DAO naming (name and symbol)
    /// @param daoUid Unique id of the DAO
    /// @param payload Encoded ITokenomics.DaoNames struct
    function updateNaming(uint daoUid, bytes memory payload) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        ITokenomics.DaoNames memory _daoNames = HostEncodingLib.decodeDaoNames(payload);

        require($.daoUids[_daoNames.symbol] == 0, IHost.SymbolNotUnique(_daoNames.symbol));

        updateNaming(daoUid, _daoNames);
    }

    function updateNaming(uint daoUid, ITokenomics.DaoNames memory daoNames_) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        // We assume here that new symbol cannot be changed by any other DAO on any chain
        // Admin validates all renaming requests.
        // Validation guarantees that new symbol is not used and not requested by any other DAO at the moment of renaming.

        string memory oldSymbol = $.segment2[daoUid].symbol;
        delete $.daoUids[oldSymbol];

        $.segment2[daoUid].symbol = daoNames_.symbol;
        $.segment2[daoUid].name = daoNames_.name;
        $.daoUids[daoNames_.symbol] = daoUid;

        emit IHost.DaoNamingUpdated(daoUid, daoNames_);

        HostCrossChainLib.sendMessageToAllChains(
            IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1,
            HostCrossChainLib.packMessageRenameSymbol(oldSymbol, daoNames_.symbol)
        );
    }

    function updateDaoParameters(uint daoUid, bytes memory payload) internal {
        ITokenomics.DaoParameters memory _daoParameters = HostEncodingLib.decodeDaoParameters(payload);
        updateDaoParameters(daoUid, _daoParameters);
    }

    function updateDaoParameters(uint daoUid, ITokenomics.DaoParameters memory daoParameters_) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoParameters[daoUid] = daoParameters_;
        emit IHost.DaoParametersUpdated(daoUid, daoParameters_);
    }

    function updateSalt(uint daoUid, bytes memory payload) internal {
        (uint16[] memory contractIndices, bytes32[] memory salt) = HostEncodingLib.decodeSalt(payload);
        updateSalt(daoUid, contractIndices, salt);
    }

    function updateSalt(uint daoUid, uint16[] memory contractIndices, bytes32[] memory salt_) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint len = contractIndices.length;
        for (uint i; i < len; ++i) {
            bytes32 key = HostLib.getKey(daoUid, contractIndices[i]);
            $.salt[key] = salt_[i];
            $.daoUidBySalt[salt_[i]] = daoUid;
        }

        emit IHost.SaltUpdated(daoUid, contractIndices, salt_);
    }

    function updateDaoChainSettings(uint daoUid, bytes memory payload) internal {
        ITokenomics.DaoChainSettings memory settings_ = HostEncodingLib.decodeDaoChainSettings(payload);
        updateDaoChainSettings(daoUid, settings_);
    }

    function updateDaoChainSettings(uint daoUid, ITokenomics.DaoChainSettings memory settings_) internal {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.chainSettings[daoUid] = settings_;
        emit IHost.DaoChainSettingsUpdated(daoUid, settings_);
    }
    //endregion -------------------------------------- Update logic
}
