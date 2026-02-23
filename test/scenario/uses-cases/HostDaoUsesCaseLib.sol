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

/// @dev Set of DAO HOST related functions ready to be used in integration tests
library HostDaoUsesCaseLib {
    string internal constant HOST_DAO_SYMBOL = "HOST";
    string internal constant HOST_DAO_NAME = "DAO Host";

    /// @dev Create DAO "host" - first DAO in the host
    /// @dev User should have enough assets (see PriceDAO} on balance
    function createHostDao(Vm vm, EngineLib.Context memory context) internal returns (IDAOData.DaoData memory dao) {
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
                .createDAO(HOST_DAO_NAME, HOST_DAO_SYMBOL, getHostActivity(), getHostDaoParameters(), getHostFunding());
            vm.stopPrank();
        }

        // 2. --------------------------- Update images
        UpdateIntentsLib.updateImages(
            vm,
            context.core,
            UpdateIntentsLib.IntentUpdateImages({
                signer: context.user, symbol: HOST_DAO_SYMBOL, images: getHostDaoImages()
            })
        );

        // 3. --------------------------- Update socials, validator validates the proposal immediately
        {
            bytes memory payload = UpdateIntentsLib.updateSocials(
                vm,
                context.core,
                UpdateIntentsLib.IntentUpdateSocials({
                    signer: context.user, symbol: HOST_DAO_SYMBOL, data: getHostSocials()
                })
            );

            bytes32 proposalId = HostUtilsLib.getLastProposalId(context.core.host, HOST_DAO_SYMBOL);

            vm.prank(context.core.hostValidator);
            context.core.host.validateProposal(proposalId, true, payload);
        }

        // 4. --------------------------- Update salts
        {
            (bytes32[] memory salts, uint16[] memory contractIndices) = getHostSalts(context.bc);
            UpdateIntentsLib.updateSalts(
                vm,
                context.core,
                UpdateIntentsLib.IntentUpdateSalts({
                    signer: context.user, symbol: HOST_DAO_SYMBOL, salts: salts, contractIndices: contractIndices
                })
            );
        }

        // 5. --------------------------- Update chain settings
        UpdateIntentsLib.updateDaoChainSettings(
            vm,
            context.core,
            UpdateIntentsLib.IntentUpdateDaoChainSettings({
                signer: context.user,
                symbol: HOST_DAO_SYMBOL,
                params: getHostChainSettings(
                    // DAO multisig is equal to Host multisig in this case
                    context.core.multisig
                )
            })
        );

        // 6. --------------------------- Update units
        {
            (IDAOData.UnitDataInput[] memory data, IDAOData.UnitEmitData[] memory emitData) = getHostUnits();

            UpdateIntentsLib.updateUnits(
                vm,
                context.core,
                UpdateIntentsLib.IntentUpdateUnits({
                    signer: context.user, symbol: HOST_DAO_SYMBOL, data: data, emitData: emitData
                })
            );
        }

        dao = context.core.dataReader.getDAO(HOST_DAO_SYMBOL);

        require(context.core.host.hostDaoUid() == dao.uid, "HOST dao is created");
    }

    //    /// @dev Register HOST DAO on bridged chain
    //    function bridgeHostToChain(Vm vm, EngineLib.Context memory ctxFrom, EngineLib.Context memory ctxTo) internal {
    //        vm.selectFork(ctxFrom.core.fork);
    //        uint hostDaoUid = ctxFrom.core.host.hostDaoUid();
    //
    //        vm.selectFork(ctxTo.core.fork);
    //
    //
    //    }

    //region --------------------------------------- Default HOST DAO parameters
    function getHostDaoParameters() internal pure returns (IDAOData.DaoParameters memory params) {
        params = IDAOData.DaoParameters({
            vePeriod: 365,
            pvpFee: 100e5,
            minPower: 0,
            ttBribe: 0,
            recoveryShare: 0,
            proposalThreshold: 0,
            totalSupply: 10_000_000e18
        });
    }

    function getHostDaoImages() internal pure returns (IDAOData.DaoImages memory images) {
        images = IDAOData.DaoImages({
            seedToken: "/HOSTseed.png", // todo use real value
            tgeToken: "/HOSTtge.png", // todo use real value
            token: "/HOST.png",
            xToken: "",
            daoToken: ""
        });
    }

    function getHostActivity() internal pure returns (IDAOData.Activity[] memory activity) {
        activity = new IDAOData.Activity[](1);
        activity[0] = IDAOData.Activity.DEFI_PROTOCOL_OPERATOR_0;
    }

    function getHostFunding() internal pure returns (IDAOData.Funding[] memory funding) {
        funding = new IDAOData.Funding[](2);
        funding[0] = IDAOData.Funding({
            fundingType: IDAOData.FundingType.SEED_0,
            start: 1775001600, // Wednesday, 1 April 2026
            end: 1780272000, // Monday, 1 June 2026
            claim: 0,
            minRaise: 40000e8,
            maxRaise: 500000e8,
            raised: 0
        });
        funding[1] = IDAOData.Funding({
            fundingType: IDAOData.FundingType.TGE_1,
            start: 1793577600, // Monday, 2 November 2026
            end: 1794182399, // Sunday, 8 November 2026, 23:59:59
            claim: 1794268800, // Tuesday, 10 November 2026
            minRaise: 400000e8,
            maxRaise: 1200000e8,
            raised: 0
        });
    }

    function getHostSalts(
        EngineLib.BaseContext memory bc
    ) internal view returns (bytes32[] memory salts, uint16[] memory contractIndices) {
        salts = new bytes32[](8);
        salts[0] = bc.config.get(bc.chainId, "SALT_HOST_SEED_TOKEN").toBytes32();
        salts[1] = bc.config.get(bc.chainId, "SALT_HOST_TGE_TOKEN").toBytes32();
        salts[2] = bc.config.get(bc.chainId, "SALT_HOST_TOKEN").toBytes32();
        salts[3] = bc.config.get(bc.chainId, "SALT_HOST_X_TOKEN").toBytes32();
        salts[4] = bc.config.get(bc.chainId, "SALT_HOST_DAO_TOKEN").toBytes32();
        salts[5] = bc.config.get(bc.chainId, "SALT_HOST_STAKING").toBytes32();
        salts[6] = bc.config.get(bc.chainId, "SALT_HOST_TOKEN_BRIDGE").toBytes32();
        salts[7] = bc.config.get(bc.chainId, "SALT_HOST_X_TOKEN_BRIDGE").toBytes32();

        contractIndices = new uint16[](8);
        contractIndices[0] = uint16(IDAOData.ContractIndices.SEED_TOKEN_1);
        contractIndices[1] = uint16(IDAOData.ContractIndices.TGE_TOKEN_2);
        contractIndices[2] = uint16(IDAOData.ContractIndices.TOKEN_3);
        contractIndices[3] = uint16(IDAOData.ContractIndices.X_TOKEN_4);
        contractIndices[4] = uint16(IDAOData.ContractIndices.DAO_TOKEN_5);
        contractIndices[5] = uint16(IDAOData.ContractIndices.STAKING_6);
        contractIndices[6] = uint16(IDAOData.ContractIndices.TOKEN_BRIDGE_8);
        contractIndices[7] = uint16(IDAOData.ContractIndices.X_TOKEN_BRIDGE_9);
    }

    function getHostChainSettings(address multisig)
        internal
        pure
        returns (IDAOData.DaoChainSettings memory chainSettings)
    {
        chainSettings = IDAOData.DaoChainSettings({bbRate: 20, multisig: multisig});
    }

    function getHostSocials() internal pure returns (string[] memory socials) {
        socials = new string[](3);
        socials[0] = "https://x.com/dao__host";
        socials[1] = "https://t.me/dao_host";
        socials[2] = "https://github.com/daohost";
    }

    function getHostUnits()
        internal
        pure
        returns (IDAOData.UnitDataInput[] memory data, IDAOData.UnitEmitData[] memory emitData)
    {
        data = new IDAOData.UnitDataInput[](1);
        data[0] = IDAOData.UnitDataInput({
            unitId: "core",
            developerUid: "" // todo do we need developerId for host dao?
        });

        string[] memory repos = new string[](4);
        repos[0] = "daohost/host";
        repos[1] = "daohost/host-contracts";
        repos[2] = "daohost/host-agent";
        repos[3] = "daohost/host-ui";

        emitData = new IDAOData.UnitEmitData[](1);
        emitData[0] = ISegment4.UnitEmitData({
            name: "dao.host",
            description: "Core unit of the Host DAO",
            status: ISegment4.UnitStatus.BUILDING_PROTOTYPE_1,
            revenueShare: 100,
            unitType: ISegment4.UnitType.DEFI_PROTOCOL_1,
            emoji: "tree",
            ui: new ISegment4.UnitUiLink[](1),
            pool: ISegment4.UnitPool({
                repos: repos,
                label: ISegment4.GithubLabel({name: "HOST:dao.host", description: "Building Host", color: "#00b243"}),
                contractorSymbol: "" // todo real value
            }),
            api: new string[](0)
        });

        emitData[0].ui[0] = ISegment4.UnitUiLink({href: "https://dao.host", title: "dao.host"});
    }

    //endregion --------------------------------------- Default HOST DAO parameters
}
