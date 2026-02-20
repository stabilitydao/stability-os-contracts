// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {Vm} from "forge-std/Test.sol";
import {EventUtilsLib} from "../../utils/EventUtilsLib.sol";

// import {console} from "forge-std/console.sol";

/// @dev All update-related intents
library UpdateIntentsLib {
    //region --------------------------------------- Intents data types
    struct IntentUpdateImages {
        address signer;
        string symbol;
        IDAOData.DaoImages images;
    }

    struct IntentUpdateSocials {
        address signer;
        string symbol;
        string[] data;
    }

    struct IntentUpdateNaming {
        address signer;
        string symbol;
        string newSymbol;
        string newName;
    }

    struct IntentUpdateUnits {
        address signer;
        string symbol;
        IDAOData.UnitDataInput[] data;
        IDAOData.UnitEmitData[] emitData;
    }

    struct IntentUpdateFunding {
        address signer;
        string symbol;
        IDAOData.Funding funding;
    }

    struct IntentUpdateVesting {
        address signer;
        string symbol;
        IDAOData.Vesting[] vesting;
    }

    struct IntentUpdateDaoParameters {
        address signer;
        string symbol;
        IDAOData.DaoParameters params;
    }

    struct IntentUpdateSalts {
        address signer;
        string symbol;
        bytes32[] salts;
        uint16[] contractIndices;
    }

    struct IntentUpdateDaoChainSettings {
        address signer;
        string symbol;
        IDAOData.DaoChainSettings params;
    }

    struct IntentUpdateGovernanceSettings {
        address signer;
        string symbol;
        IDAOData.GovernanceSettings params;
    }

    //endregion --------------------------------------- Intents data types

    //region --------------------------------------- Update actions
    function updateImages(
        Vm vm,
        EngineLib.Core memory core,
        IntentUpdateImages memory intent
    ) internal returns (bytes memory payload) {
        payload = core.hostCodec.encode(intent.images, core.hostCodec.PAYLOAD_API_VERSION());

        vm.prank(intent.signer);
        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_IMAGES_0), payload, "");
    }

    function updateSocials(
        Vm vm,
        EngineLib.Core memory core,
        IntentUpdateSocials memory intent
    ) internal returns (bytes memory payload) {
        payload = core.hostCodec.encode(intent.data, core.hostCodec.PAYLOAD_API_VERSION());

        vm.prank(intent.signer);
        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_SOCIALS_1), payload, "");
    }

    function updateNaming(
        Vm vm,
        EngineLib.Core memory core,
        IntentUpdateNaming memory intent
    ) internal returns (bytes memory payload) {
        IDAOData.DaoNames memory data = IDAOData.DaoNames({name: intent.newName, symbol: intent.newSymbol});
        payload = core.hostCodec.encode(data, core.hostCodec.PAYLOAD_API_VERSION());

        vm.prank(intent.signer);
        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_NAMING_2), payload, "");
    }

    function updateUnits(
        Vm vm,
        EngineLib.Core memory core,
        IntentUpdateUnits memory intent
    ) internal returns (bytes memory payload) {
        payload = core.hostCodec.encode(intent.data, core.hostCodec.PAYLOAD_API_VERSION());
        bytes memory payloadEmit = core.hostCodec.encode(intent.emitData, core.hostCodec.PAYLOAD_API_VERSION());

        vm.recordLogs();

        vm.prank(intent.signer);
        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_UNITS_3), payload, payloadEmit);
    }

    function updateFunding(
        Vm vm,
        EngineLib.Core memory core,
        IntentUpdateFunding memory intent
    ) internal returns (bytes memory payload) {
        payload = core.hostCodec.encode(intent.funding, core.hostCodec.PAYLOAD_API_VERSION());

        vm.prank(intent.signer);
        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_FUNDING_4), payload, "");
    }

    function updateVesting(
        Vm vm,
        EngineLib.Core memory core,
        IntentUpdateVesting memory intent
    ) internal returns (bytes memory payload) {
        payload = core.hostCodec.encode(intent.vesting, core.hostCodec.PAYLOAD_API_VERSION());

        vm.prank(intent.signer);
        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_VESTING_5), payload, "");
    }

    function updateDaoParameters(
        Vm vm,
        EngineLib.Core memory core,
        IntentUpdateDaoParameters memory intent
    ) internal returns (bytes memory payload) {
        payload = core.hostCodec.encode(intent.params, core.hostCodec.PAYLOAD_API_VERSION());

        vm.prank(intent.signer);
        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_DAO_PARAMETERS_6), payload, "");
    }

    function updateSalts(
        Vm vm,
        EngineLib.Core memory core,
        IntentUpdateSalts memory intent
    ) internal returns (bytes memory payload) {
        payload = core.hostCodec.encode(intent.contractIndices, intent.salts, core.hostCodec.PAYLOAD_API_VERSION());

        vm.prank(intent.signer);
        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_SALT_7), payload, "");
    }

    function updateDaoChainSettings(
        Vm vm,
        EngineLib.Core memory core,
        IntentUpdateDaoChainSettings memory intent
    ) internal returns (bytes memory payload) {
        payload = core.hostCodec.encode(intent.params, core.hostCodec.PAYLOAD_API_VERSION());

        vm.prank(intent.signer);
        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_DAO_CHAIN_SETTINGS_8), payload, "");
    }

    function updateGovernanceSettings(
        Vm vm,
        EngineLib.Core memory core,
        IntentUpdateGovernanceSettings memory intent
    ) internal returns (bytes memory payload) {
        payload = core.hostCodec.encode(intent.params, core.hostCodec.PAYLOAD_API_VERSION());

        vm.prank(intent.signer);
        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_GOVERNANCE_SETTINGS_10), payload, "");
    }
    //endregion --------------------------------------- Update actions
}
