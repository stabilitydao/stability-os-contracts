// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
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
    string internal constant MEVBOTS_DAO_SYMBOL = "MEVBOTS";
    string internal constant MEVBOTS_DAO_NAME = "MEV Machines";
    bytes32 internal constant MEVBOTS_SALT_SEED_TOKEN = 0xce4effbbe3dba0a28d68fe6584e88165ba2a39782cf737cb4864a5b02be9f6ed;
    bytes32 internal constant MEVBOTS_SALT_TGE_TOKEN = 0xc8a9d2a62d142f596413fc1a84af18b3cd3cfd0fb7f1f304a20c335f04eb94e8;
    bytes32 internal constant MEVBOTS_SALT_TOKEN = 0x8fc8bb7c859462873fd4de28df77eb5c0b992ed92e363a52e5e3bbecb6521644;
    bytes32 internal constant MEVBOTS_SALT_X_TOKEN = 0x80f98a15e0b5b0ae7fdca5b6c2dc2313cc5b0ed83bfddc08fb9fa81c19a3297e;
    bytes32 internal constant MEVBOTS_SALT_DAO_TOKEN = 0x41431bb0020c6598ee776b162ba7a777d2998acb844aa1d64b26a21fc36fa26f;

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
                    MEVBOTS_DAO_NAME,
                    MEVBOTS_DAO_SYMBOL,
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
                signer: context.user, symbol: MEVBOTS_DAO_SYMBOL, images: getMevBotDaoImages()
            })
        );

        // 3. --------------------------- Update socials, validator validates the proposal immediately
        {
            UpdateIntentsLib.updateSocials(
                vm,
                context.core,
                UpdateIntentsLib.IntentUpdateSocials({
                    signer: context.user, symbol: MEVBOTS_DAO_SYMBOL, data: getMevBotSocials()
                })
            );
        }

        // 4. --------------------------- Update salts
        {
            (bytes32[] memory salts, uint16[] memory contractIndices) = getMevBotSalts();
            UpdateIntentsLib.updateSalts(
                vm,
                context.core,
                UpdateIntentsLib.IntentUpdateSalts({
                    signer: context.user, symbol: MEVBOTS_DAO_SYMBOL, salts: salts, contractIndices: contractIndices
                })
            );
        }

        // 5. --------------------------- Update chain settings
        UpdateIntentsLib.updateDaoChainSettings(
            vm,
            context.core,
            UpdateIntentsLib.IntentUpdateDaoChainSettings({
                signer: context.user,
                symbol: MEVBOTS_DAO_SYMBOL,
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
                    signer: context.user, symbol: MEVBOTS_DAO_SYMBOL, data: data, emitData: emitData
                })
            );
        }

        dao = context.core.dataReader.getDAO(MEVBOTS_DAO_SYMBOL);
    }

    //region --------------------------------------- Default MEVBOT parameters
    function getMevBotDaoParameters() internal pure returns (IDAOData.DaoParameters memory params) {
        params = IDAOData.DaoParameters({
            vePeriod: 360,
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
            seedToken: "/seedMEVBOTS.png",
            tgeToken: "/tgeMEVBOTS.png",
            token: "/mevbots.png",
            xToken: "/xMEVBOTS.png",
            daoToken: "/daoMEVBOTS.png"
        });
    }

    function getMevBotActivity() internal pure returns (IDAOData.Activity[] memory activity) {
        activity = new IDAOData.Activity[](1);
        activity[0] = IDAOData.Activity.MEV_1;
    }

    function getMevBotFunding() internal pure returns (IDAOData.Funding[] memory funding) {
        funding = new IDAOData.Funding[](2);
        funding[0] = IDAOData.Funding({
            fundingType: IDAOData.FundingType.SEED_0,
            start: 1785769200 - 1800, // 3 aug 2026 15:00
            end: 1809097200, // 30 apr 2027
            claim: 0,
            minRaise: 10_000e8,
            maxRaise: 10_000_000e8,
            raised: 0
        });
        funding[1] = IDAOData.Funding({
            fundingType: IDAOData.FundingType.TGE_1,
            start: 1827619200, // 1 dec 2027
            end: 1828223999, // 7 dec 2027
            claim: 0,
            minRaise: 1_000_000e8,
            maxRaise: 1_500_000e8,
            raised: 0
        });
    }

    function getMevBotSalts() internal pure returns (bytes32[] memory salts, uint16[] memory contractIndices) {
        salts = new bytes32[](5);
        contractIndices = new uint16[](5);

        salts[0] = MEVBOTS_SALT_SEED_TOKEN;
        salts[1] = MEVBOTS_SALT_TGE_TOKEN;
        salts[2] = MEVBOTS_SALT_TOKEN;
        salts[3] = MEVBOTS_SALT_X_TOKEN;
        salts[4] = MEVBOTS_SALT_DAO_TOKEN;
        contractIndices[0] = uint16(IDAOData.ContractIndices.SEED_TOKEN_1);
        contractIndices[1] = uint16(IDAOData.ContractIndices.TGE_TOKEN_2);
        contractIndices[2] = uint16(IDAOData.ContractIndices.TOKEN_3);
        contractIndices[3] = uint16(IDAOData.ContractIndices.X_TOKEN_4);
        contractIndices[4] = uint16(IDAOData.ContractIndices.DAO_TOKEN_5);
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
        socials[0] = "https://t.me/mevmachines";
        socials[1] = "https://github.com/mevmachines";
    }

    function getMevBotUnits()
        internal
        pure
        returns (IDAOData.UnitDataInput[] memory data, IDAOData.UnitEmitData[] memory emitData)
    {
        data = new IDAOData.UnitDataInput[](1);
        data[0] = IDAOData.UnitDataInput({unitId: "mevminer", developerUid: ""});

        string[] memory repos = new string[](1);
        repos[0] = "mevmachines/mevminer";

        emitData = new IDAOData.UnitEmitData[](1);
        emitData[0] = ISegment4.UnitEmitData({
            name: "mevminer",
            description: "Ethereum MEV Searcher",
            status: ISegment4.UnitStatus.PROTOTYPE_2,
            revenueShare: 50,
            unitType: ISegment4.UnitType.MEV_SEARCHER_2,
            emoji: ":robot:",
            ui: new ISegment4.UnitUiLink[](0),
            pool: ISegment4.UnitPool({
                repos: repos,
                label: ISegment4.GithubLabel({
                    name: "track:by:host", description: "Issue for tracking by Host Agent", color: "#ae4cff"
                }),
                contractorSymbol: ""
            }),
            api: new string[](0)
        });
    }

    //endregion --------------------------------------- Default MEVBOT parameters
}
