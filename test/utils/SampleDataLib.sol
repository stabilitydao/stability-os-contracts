// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDAOMetadata} from "../../src/interfaces/IDAOMetadata.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {IBridgedActions} from "../../src/interfaces/IBridgedActions.sol";

library SampleDataLib {
    function getUnitPoolSample() internal pure returns (IDAOData.UnitPool memory) {
        return IDAOMetadata.UnitPool({
            repos: new string[](0),
            label: IDAOMetadata.GithubLabel({
                name: "protocolA", description: "Unit 0 Protocol A tasks", color: "0000FF"
            }),
            contractorSymbol: "PA"
        });
    }

    function getBridgeDaoParams() internal pure returns (IBridgedActions.BridgeDaoParams memory) {
        IBridgedActions.BridgeDaoParams memory p = IBridgedActions.BridgeDaoParams({
            symbol: "SYMBOL",
            name: "NAME",
            unitIds: new string[](2),
            chainSettings: ITokenomics.DaoChainSettings({bbRate: 10, multisig: address(0x123)}),
            daoParameters: ITokenomics.DaoParameters({
                vePeriod: 1, pvpFee: 2, minPower: 3, ttBribe: 4, recoveryShare: 5, proposalThreshold: 6, totalSupply: 7
            }),
            saltContractIndices: new uint16[](1),
            salts: new bytes32[](1)
        });

        p.unitIds[0] = "unit1";
        p.unitIds[1] = "unit2";

        p.salts[0] = bytes32("0xabc");
        p.saltContractIndices[0] = uint16(ITokenomics.ContractIndices.DAO_TOKEN_5);

        return p;
    }

    function getDaoChainSettings() internal pure returns (ITokenomics.DaoChainSettings memory) {
        return ITokenomics.DaoChainSettings({bbRate: 10, multisig: address(0x123)});
    }

    function getDaoParameters() internal pure returns (ITokenomics.DaoParameters memory) {
        return ITokenomics.DaoParameters({
            vePeriod: 1, pvpFee: 2, minPower: 3, ttBribe: 4, recoveryShare: 5, proposalThreshold: 6, totalSupply: 7
        });
    }

    function getSalts() internal pure returns (uint16[] memory contractIndices, bytes32[] memory salt) {
        contractIndices = new uint16[](3);
        salt = new bytes32[](3);

        contractIndices[0] = uint16(ITokenomics.ContractIndices.DAO_TOKEN_5);
        contractIndices[1] = uint16(ITokenomics.ContractIndices.DAO_TOKEN_BRIDGE_10);
        contractIndices[2] = uint16(ITokenomics.ContractIndices.STAKING_6);
        salt[0] = bytes32("0xabc1");
        salt[1] = bytes32("0xabc2");
        salt[2] = bytes32("0xabc3");
    }

    function getDaoImages() internal pure returns (ITokenomics.DaoImages memory) {
        return ITokenomics.DaoImages({
            seedToken: "images/seed.png",
            tgeToken: "images/tge.png",
            token: "images/token.png",
            xToken: "images/xtoken.png",
            daoToken: "images/daotoken.png"
        });
    }

    function getUnitsSingle()
        internal
        pure
        returns (IDAOData.UnitDataInput[] memory units, IDAOMetadata.UnitMetaData[] memory metas)
    {
        return getUnitsSingle("unit1");
    }

    function getUnitsSingle(string memory unitId)
        internal
        pure
        returns (IDAOData.UnitDataInput[] memory units, IDAOMetadata.UnitMetaData[] memory metas)
    {
        units = new IDAOData.UnitDataInput[](1);
        metas = new IDAOMetadata.UnitMetaData[](1);

        metas[0] = IDAOMetadata.UnitMetaData({
            name: "abc",
            status: IDAOMetadata.UnitStatus.BUILDING_1,
            unitType: uint16(IDAOMetadata.UnitType.DEFI_PROTOCOL_1),
            revenueShare: 100,
            ui: new IDAOMetadata.UnitUiLink[](1),
            emoji: "emoji",
            api: new string[](2),
            pool: SampleDataLib.getUnitPoolSample()
        });
        units[0] = IDAOData.UnitDataInput({unitId: unitId, developerUid: "d1"});

        metas[0].api[0] = "https://api.aa/a";
        metas[0].api[1] = "https://api.bb/b";

        metas[0].ui[0] = IDAOMetadata.UnitUiLink({href: "https://mvp.ui", title: "OS MVO"});
    }

    function getUnitsTwo()
        internal
        pure
        returns (IDAOData.UnitDataInput[] memory units, IDAOMetadata.UnitMetaData[] memory metas)
    {
        units = new IDAOData.UnitDataInput[](2);
        metas = new IDAOMetadata.UnitMetaData[](2);

        metas[0] = IDAOMetadata.UnitMetaData({
            name: "abc",
            status: IDAOMetadata.UnitStatus.LIVE_2,
            unitType: uint16(IDAOMetadata.UnitType.PVP_0),
            revenueShare: 100,
            ui: new IDAOMetadata.UnitUiLink[](1),
            emoji: "emoji",
            api: new string[](2),
            pool: SampleDataLib.getUnitPoolSample()
        });
        units[0] = IDAOData.UnitDataInput({unitId: "unit1", developerUid: "d1"});
        metas[1] = IDAOMetadata.UnitMetaData({
            name: "abc",
            status: IDAOMetadata.UnitStatus.BUILDING_1,
            unitType: uint16(IDAOMetadata.UnitType.SAAS_2),
            revenueShare: 1,
            ui: new IDAOMetadata.UnitUiLink[](2),
            emoji: "emoji",
            api: new string[](1),
            pool: SampleDataLib.getUnitPoolSample()
        });
        units[1] = IDAOData.UnitDataInput({unitId: "unit2", developerUid: "d2"});
        metas[1].api[0] = "https://api.aa/a";

        metas[0].api[0] = "https://api.aa/a";
        metas[0].api[1] = "https://api.bb/b";

        metas[0].ui[0] = IDAOMetadata.UnitUiLink({href: "https://mvp.ui", title: "OS MVO"});

        metas[1].ui[0] = IDAOMetadata.UnitUiLink({href: "https://mvp.ui1", title: "t1"});
        metas[1].ui[1] = IDAOMetadata.UnitUiLink({href: "https://mvp.ui2222", title: "OS MVO2"});
    }

    function getUnitsThree()
        internal
        pure
        returns (IDAOData.UnitDataInput[] memory units, IDAOMetadata.UnitMetaData[] memory metas)
    {
        units = new IDAOData.UnitDataInput[](3);
        metas = new IDAOMetadata.UnitMetaData[](3);

        { // Unit 0: one UI link, two API endpoints
            IDAOMetadata.UnitUiLink[] memory ui0 = new IDAOMetadata.UnitUiLink[](1);
            ui0[0] = IDAOMetadata.UnitUiLink({title: "Dashboard", href: "https://unit0.example/dashboard"});

            string[] memory api0 = new string[](2);
            api0[0] = "https://api.unit0.example/v1/status";
            api0[1] = "https://api.unit0.example/v1/metrics";

            metas[0] = IDAOMetadata.UnitMetaData({
                name: "Protocol A",
                status: IDAOMetadata.UnitStatus.RESEARCH_0,
                unitType: uint16(IDAOMetadata.UnitType.DEFI_PROTOCOL_1),
                revenueShare: 20000,
                emoji: "zzz",
                ui: ui0,
                api: api0,
                pool: SampleDataLib.getUnitPoolSample()
            });
            units[0] = IDAOData.UnitDataInput({unitId: "defi:protocolA", developerUid: ""});
        }

        { // Unit 1: two UI links, one API endpoint
            IDAOMetadata.UnitUiLink[] memory ui1 = new IDAOMetadata.UnitUiLink[](2);
            ui1[0] = IDAOMetadata.UnitUiLink({title: "App", href: "https://unit1.example/app"});
            ui1[1] = IDAOMetadata.UnitUiLink({title: "Docs", href: "https://unit1.example/docs"});

            string[] memory api1 = new string[](1);
            api1[0] = "https://api.unit1.example/";

            metas[1] = IDAOMetadata.UnitMetaData({
                name: "Service X",
                status: IDAOMetadata.UnitStatus.BUILDING_1,
                unitType: uint16(IDAOMetadata.UnitType.SAAS_2),
                revenueShare: 50000,
                emoji: "aaa",
                ui: ui1,
                api: api1,
                pool: SampleDataLib.getUnitPoolSample()
            });
            units[1] = IDAOData.UnitDataInput({unitId: "saas:serviceX", developerUid: ""});
        }

        { // Unit 2: no UI links, empty api array
            IDAOMetadata.UnitUiLink[] memory ui2 = new IDAOMetadata.UnitUiLink[](0);
            string[] memory api2 = new string[](0);

            metas[2] = IDAOMetadata.UnitMetaData({
                name: "MEV Bot Z",
                status: IDAOMetadata.UnitStatus.LIVE_2,
                unitType: uint16(IDAOMetadata.UnitType.MEV_3),
                revenueShare: 80000,
                emoji: "aaaaaaaa",
                ui: ui2,
                api: api2,
                pool: SampleDataLib.getUnitPoolSample()
            });
            units[2] = IDAOData.UnitDataInput({unitId: "mev:botZ", developerUid: ""});
        }
    }

    function getSocialsThree() internal pure returns (string[] memory) {
        string[] memory socials = new string[](3);
        socials[0] = "twitter:@aliens";
        socials[1] = "discord:/aliens";
        socials[2] = "website:https://aliens.example";
        return socials;
    }
}
