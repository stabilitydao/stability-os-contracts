// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpdateIntentsLib} from "../commands/UpdateIntentsLib.sol";
import {DeployIntentsLib} from "../commands/DeployIntentsLib.sol";
import {EngineLib} from "../engine/EngineLib.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";
import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {IHostCodec} from "../../../src/interfaces/IHostCodec.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";

/// @dev Set of createDAO-related functions ready to be used in integration tests
library CreateDaoUsesCaseLib {
    string constant internal HOST_DAO_SYMBOL = "HOST";
    string constant internal HOST_DAO_NAME = "DAO Host";

    /// @dev Create DAO "host" - first DAO in the host
    /// @dev User should have enough assets (see PriceDAO} on balance
    function createHostDao(EngineLib.Core memory core) internal returns (IDAOData.DaoData memory dao) {
        // 1. --------------------------- Create DAO
        {

            uint priceDao = core.host.getSettings().priceDao;
            address exchangeAsset = core.host.getChainSettings().exchangeAsset;

            /// @dev We are going to pay {priceDao} in exchange asset to host
            IERC20(exchangeAsset).approve(address(core.host), priceDao);

            /// @dev create host dao
            core.host.createDAO(
                HOST_DAO_NAME,
                HOST_DAO_SYMBOL,
                getHostActivity(),
                getHostDaoParameters(),
                getHostFunding()
            );
        }

        // 2. --------------------------- Update images
        UpdateIntentsLib.updateImages(core, UpdateIntentsLib.IntentUpdateImages({symbol: HOST_DAO_SYMBOL, images: getHostDaoImages()}));


        // 3. --------------------------- Update units

        // 4. --------------------------- Update salts

        // 5. --------------------------- Update chain settings


        dao = core.dataReader.getDAO(HOST_DAO_SYMBOL);

        require(core.host.hostDaoUid() == dao.uid, "HOST dao is created");
    }


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
            seedToken: "",
            tgeToken: "",
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

    function getHostSalts() internal pure returns (bytes32[] memory salts, uint16[] memory contractIndices) {
        salts = new bytes32[](1);
        salts[0] = bytes32(abi.encodePacked(HOST_DAO_SYMBOL));
    }
}