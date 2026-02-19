// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
import {HostBridge} from "../../../src/HostBridge.sol";
import {AccessRolesLib} from "../../../src/libs/AccessRolesLib.sol";
import {AuthorityAccessUtils} from "../access/AuthorityAccessUtils.sol";
import {Authority} from "../../../src/Authority.sol";
import {Host} from "../../../src/Host.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAuthority} from "../../../src/interfaces/IAuthority.sol";
import {IHosted} from "../../../src/interfaces/IHosted.sol";
import {IHost} from "../../../src/interfaces/IHost.sol";
import {IHostBridge} from "../../../src/interfaces/IHostBridge.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {IProxyFactory} from "../../../src/interfaces/IProxyFactory.sol";
import {StdConfig} from "forge-std/StdConfig.sol";
import {IHostCodec} from "../../../src/interfaces/IHostCodec.sol";
import {HostCodec} from "../../../src/HostCodec.sol";
import {IDataReader} from "../../../src/interfaces/IDataReader.sol";
import {IDAOData} from "../../../src/interfaces/IDAOData.sol";
import {EngineLib} from "../engine/EngineLib.sol";

// import {console} from "forge-std/console.sol";

/// @dev All update-related intents
library UpdateIntentsLib {
    //region --------------------------------------- Intents data types
    struct IntentUpdateImages {
        string symbol;
        IDAOData.DaoImages images;
    }

    //endregion --------------------------------------- Intents data types

    //region --------------------------------------- Update images
    function updateImages(EngineLib.Core memory core, IntentUpdateImages memory intent) internal {
        bytes memory payload = core.hostCodec.encode(intent.images, core.hostCodec.PAYLOAD_API_VERSION());

        core.host.updateDAO(intent.symbol, uint16(IDAOData.DAOAction.UPDATE_IMAGES_0), payload, "");
    }

    //endregion --------------------------------------- Update images
}