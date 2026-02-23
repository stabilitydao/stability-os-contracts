// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
// import {PrintUtilsLib} from "../../utils/PrintUtilsLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {HostUtilsLib} from "../../utils/HostUtilsLib.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISegment4} from "../../../src/interfaces/ISegment4.sol";
import {UpdateIntentsLib} from "../commands/UpdateIntentsLib.sol";
import {Vm} from "forge-std/Test.sol";

/// @dev Set of DAO "not HOST" related functions ready to be used in integration tests
library MevBotDaoUsesCaseLib {
    string internal constant MEVBOT_DAO_SYMBOL = "MEVBOT";
    string internal constant MEVBOT_DAO_NAME = "MEV Bot";

    /// @dev Create DAO "host" - first DAO in the host
    /// @dev User should have enough assets (see PriceDAO} on balance
    function createMevBotDao(Vm vm, EngineLib.Context memory context) internal returns (IDAOData.DaoData memory dao) {
        // 1. --------------------------- Create DAO
        {

            uint priceDao = context.core.host.getSettings().priceDao;
            address exchangeAsset = context.core.host.getChainSettings().exchangeAsset;

            /// @dev We are going to pay {priceDao} in exchange asset to host
            vm.prank(context.user);
            IERC20(exchangeAsset).approve(address(context.core.host), priceDao);

            /// @dev create host dao
            vm.startPrank(context.user);
            context.core.host
                .createDAO(
                    MEVBOT_DAO_NAME,
                    MEVBOT_DAO_SYMBOL,
                    getMevBotActivity(),
                    getMevBotDaoParameters(),
                    getMevBotFunding()
                );
            vm.stopPrank();
        }

        // 2. --------------------------- Update images
        UpdateIntentsLib.updateImages(
            vm,
            context.core,
            UpdateIntentsLib.IntentUpdateImages({
                signer: context.user, symbol: MEVBOT_DAO_SYMBOL, images: getMevBotDaoImages()
            })
        );

        // 3. --------------------------- Update socials, validator validates the proposal immediately
        {
            bytes memory payload = UpdateIntentsLib.updateSocials(
                vm,
                context.core,
                UpdateIntentsLib.IntentUpdateSocials({
                    signer: context.user, symbol: MEVBOT_DAO_SYMBOL, data: getMevBotSocials()
                })
            );

            bytes32 proposalId = HostUtilsLib.getLastProposalId(context.core.host, MEVBOT_DAO_SYMBOL);

            vm.prank(context.core.hostValidator);
            context.core.host.validateProposal(proposalId, true, payload);
        }

        // 4. --------------------------- Update salts
        {
            (bytes32[] memory salts, uint16[] memory contractIndices) = getMevBotSalts(context.bc);
            UpdateIntentsLib.updateSalts(
                vm,
                context.core,
                UpdateIntentsLib.IntentUpdateSalts({
                    signer: context.user, symbol: MEVBOT_DAO_SYMBOL, salts: salts, contractIndices: contractIndices
                })
            );
        }

        // 5. --------------------------- Update chain settings
        UpdateIntentsLib.updateDaoChainSettings(
            vm,
            context.core,
            UpdateIntentsLib.IntentUpdateDaoChainSettings({
                signer: context.user,
                symbol: MEVBOT_DAO_SYMBOL,
                params: getMevBotChainSettings(
                    // todo DAO multisig is equal to Host multisig in this case
                    context.core.multisig
                )
            })
        );

        // 6. --------------------------- Update units
        {
            (IDAOData.UnitDataInput[] memory data, IDAOData.UnitEmitData[] memory emitData) = getMevBotUnits();

            UpdateIntentsLib.updateUnits(
                vm,
                context.core,
                UpdateIntentsLib.IntentUpdateUnits({
                    signer: context.user, symbol: MEVBOT_DAO_SYMBOL, data: data, emitData: emitData
                })
            );
        }

        dao = context.core.dataReader.getDAO(MEVBOT_DAO_SYMBOL);
    }

    //region --------------------------------------- Default MEVBOT parameters
    function getMevBotDaoParameters() internal pure returns (IDAOData.DaoParameters memory params) {
        params = IDAOData.DaoParameters({
            vePeriod: 120,
            pvpFee: 100e5,
            minPower: 0,
            ttBribe: 0,
            recoveryShare: 0,
            proposalThreshold: 0,
            totalSupply: 1_000_000e18
        });
    }

    function getMevBotDaoImages() internal pure returns (IDAOData.DaoImages memory images) {
        images = IDAOData.DaoImages({
            seedToken: "/MEVBOTseed.png", // todo use real value
            tgeToken: "/MEVBOTtge.png", // todo use real value
            token: "/MEVBOT.png",
            xToken: "",
            daoToken: ""
        });
    }

    function getMevBotActivity() internal pure returns (IDAOData.Activity[] memory activity) {
        activity = new IDAOData.Activity[](1);
        activity[0] = IDAOData.Activity.MEV_SEARCHER_2;
    }

    function getMevBotFunding() internal pure returns (IDAOData.Funding[] memory funding) {
        funding = new IDAOData.Funding[](1);
        funding[0] = IDAOData.Funding({
            fundingType: IDAOData.FundingType.SEED_0,
            start: 1777593600, // Friday, 1 May 2026
            end: 1782864000, // Wednesday, 1 July 2026
            claim: 0,
            minRaise: 50000e8,
            maxRaise: 250000e8,
            raised: 0
        });
    }

    function getMevBotSalts(
        EngineLib.BaseContext memory /* bc */
    ) internal pure returns (bytes32[] memory salts, uint16[] memory contractIndices) {
        salts = new bytes32[](2);
        contractIndices = new uint16[](2);
        salts[0] = bytes32(abi.encodePacked("MEVBOT:Ethereum:SeeToken"));
        salts[1] = bytes32(abi.encodePacked("MEVBOT:Ethereum:TgeToken"));
        contractIndices[0] = uint16(IDAOData.ContractIndices.SEED_TOKEN_1); // todo use real value
        contractIndices[1] = uint16(IDAOData.ContractIndices.TGE_TOKEN_2); // todo use real value
    }

    function getMevBotChainSettings(address multisig)
        internal
        pure
        returns (IDAOData.DaoChainSettings memory chainSettings)
    {
        chainSettings = IDAOData.DaoChainSettings({bbRate: 50, multisig: multisig});
    }

    function getMevBotSocials() internal pure returns (string[] memory socials) {
        socials = new string[](2);
        socials[0] = "todo"; // todo use real value
        socials[1] = "todo"; // todo use real value
    }

    function getMevBotUnits()
        internal
        pure
        returns (IDAOData.UnitDataInput[] memory data, IDAOData.UnitEmitData[] memory emitData)
    {
        data = new IDAOData.UnitDataInput[](1);
        data[0] = IDAOData.UnitDataInput({unitId: "mevbot:ethereum", developerUid: ""});

        string[] memory repos = new string[](1);
        repos[0] = "stabilitydao/mevbot";

        emitData = new IDAOData.UnitEmitData[](1);
        emitData[0] = ISegment4.UnitEmitData({
            name: "EthereumBot",
            description: "Ethereum MEV Searcher machine",
            status: ISegment4.UnitStatus.BUILDING_PROTOTYPE_1,
            revenueShare: 100,
            unitType: ISegment4.UnitType.MEV_SEARCHER_2,
            emoji: "emoji", // todo use real value
            ui: new ISegment4.UnitUiLink[](0),
            pool: ISegment4.UnitPool({
                repos: repos,
                label: ISegment4.GithubLabel({
                    name: "MEVBOT:Ethereum", description: "Building MEVBOT for Ethereum chain", color: "#4cbaff"
                }),
                contractorSymbol: ""
            }),
            api: new string[](0)
        });
    }

    //endregion --------------------------------------- Default MEVBOT parameters
}
