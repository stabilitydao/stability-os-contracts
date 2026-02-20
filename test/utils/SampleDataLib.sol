// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";
import {IBridgedActions} from "../../src/interfaces/IBridgedActions.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {ISegment4} from "../../src/interfaces/ISegment4.sol";
import {EngineLib} from "../scenario/engine/EngineLib.sol";

library SampleDataLib {
    uint64 internal constant DEFAULT_MIN_INCEPTION_DURATION = 7 days;

    function getUnitPoolSample() internal pure returns (IDAOData.UnitPool memory) {
        return ISegment4.UnitPool({
            repos: new string[](0),
            label: ISegment4.GithubLabel({name: "protocolA", description: "Unit 0 Protocol A tasks", color: "0000FF"}),
            contractorSymbol: "PA"
        });
    }

    function getBridgeDaoParams() internal pure returns (IBridgedActions.BridgeDaoParams memory) {
        IBridgedActions.BridgeDaoParams memory p = IBridgedActions.BridgeDaoParams({
            symbol: "SYMBOL",
            name: "NAME",
            unitIds: new string[](2),
            chainSettings: IDAOData.DaoChainSettings({bbRate: 10, multisig: address(0x123)}),
            daoParameters: IDAOData.DaoParameters({
                vePeriod: 1, pvpFee: 2, minPower: 3, ttBribe: 4, recoveryShare: 5, proposalThreshold: 6, totalSupply: 7
            }),
            saltContractIndices: new uint16[](1),
            salts: new bytes32[](1)
        });

        p.unitIds[0] = "unit1";
        p.unitIds[1] = "unit2";

        p.salts[0] = bytes32("0xabc");
        p.saltContractIndices[0] = uint16(IDAOData.ContractIndices.DAO_TOKEN_5);

        return p;
    }

    function getDaoChainSettings() internal pure returns (IDAOData.DaoChainSettings memory) {
        return IDAOData.DaoChainSettings({bbRate: 10, multisig: address(0x123)});
    }

    function getDaoParameters() internal pure returns (IDAOData.DaoParameters memory) {
        return IDAOData.DaoParameters({
            vePeriod: 1, pvpFee: 2, minPower: 3, ttBribe: 4, recoveryShare: 5, proposalThreshold: 6, totalSupply: 7
        });
    }

    function getSalts() internal pure returns (uint16[] memory contractIndices, bytes32[] memory salt) {
        contractIndices = new uint16[](3);
        salt = new bytes32[](3);

        contractIndices[0] = uint16(IDAOData.ContractIndices.DAO_TOKEN_5);
        contractIndices[1] = uint16(IDAOData.ContractIndices.DAO_TOKEN_BRIDGE_10);
        contractIndices[2] = uint16(IDAOData.ContractIndices.STAKING_6);
        salt[0] = bytes32("0xabc1");
        salt[1] = bytes32("0xabc2");
        salt[2] = bytes32("0xabc3");
    }

    function getDaoImages() internal pure returns (IDAOData.DaoImages memory) {
        return IDAOData.DaoImages({
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
        returns (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory emitted)
    {
        return getUnitsSingle("unit1");
    }

    function getUnitsSingle(string memory unitId)
        internal
        pure
        returns (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory emitted)
    {
        units = new IDAOData.UnitDataInput[](1);
        emitted = new ISegment4.UnitEmitData[](1);

        emitted[0] = ISegment4.UnitEmitData({
            name: "abc",
            description: "description",
            status: ISegment4.UnitStatus.BUILDING_3,
            unitType: ISegment4.UnitType.DEFI_PROTOCOL_1,
            revenueShare: 100,
            ui: new ISegment4.UnitUiLink[](1),
            emoji: "emoji",
            api: new string[](2),
            pool: SampleDataLib.getUnitPoolSample()
        });
        units[0] = IDAOData.UnitDataInput({unitId: unitId, developerUid: "d1"});

        emitted[0].api[0] = "https://api.aa/a";
        emitted[0].api[1] = "https://api.bb/b";

        emitted[0].ui[0] = ISegment4.UnitUiLink({href: "https://mvp.ui", title: "OS MVO"});
    }

    function getUnitsTwo()
        internal
        pure
        returns (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory emitted)
    {
        units = new IDAOData.UnitDataInput[](2);
        emitted = new ISegment4.UnitEmitData[](2);

        emitted[0] = ISegment4.UnitEmitData({
            name: "abc",
            description: "description",
            status: ISegment4.UnitStatus.LIVE_4,
            unitType: ISegment4.UnitType.PVP_0,
            revenueShare: 100,
            ui: new ISegment4.UnitUiLink[](1),
            emoji: "emoji",
            api: new string[](2),
            pool: SampleDataLib.getUnitPoolSample()
        });
        units[0] = IDAOData.UnitDataInput({unitId: "unit1", developerUid: "d1"});
        emitted[1] = ISegment4.UnitEmitData({
            name: "abc",
            description: "description",
            status: ISegment4.UnitStatus.BUILDING_3,
            unitType: ISegment4.UnitType.MEV_SEARCHER_2,
            revenueShare: 1,
            ui: new ISegment4.UnitUiLink[](2),
            emoji: "emoji",
            api: new string[](1),
            pool: SampleDataLib.getUnitPoolSample()
        });
        units[1] = IDAOData.UnitDataInput({unitId: "unit2", developerUid: "d2"});
        emitted[1].api[0] = "https://api.aa/a";

        emitted[0].api[0] = "https://api.aa/a";
        emitted[0].api[1] = "https://api.bb/b";

        emitted[0].ui[0] = ISegment4.UnitUiLink({href: "https://mvp.ui", title: "OS MVO"});

        emitted[1].ui[0] = ISegment4.UnitUiLink({href: "https://mvp.ui1", title: "t1"});
        emitted[1].ui[1] = ISegment4.UnitUiLink({href: "https://mvp.ui2222", title: "OS MVO2"});
    }

    function getUnitsThree()
        internal
        pure
        returns (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory emitted)
    {
        units = new IDAOData.UnitDataInput[](3);
        emitted = new ISegment4.UnitEmitData[](3);

        { // Unit 0: one UI link, two API endpoints
            ISegment4.UnitUiLink[] memory ui0 = new ISegment4.UnitUiLink[](1);
            ui0[0] = ISegment4.UnitUiLink({title: "Dashboard", href: "https://unit0.example/dashboard"});

            string[] memory api0 = new string[](2);
            api0[0] = "https://api.unit0.example/v1/status";
            api0[1] = "https://api.unit0.example/v1/metrics";

            emitted[0] = ISegment4.UnitEmitData({
                name: "Protocol A",
                description: "A DeFi protocol that does X, Y, Z.",
                status: ISegment4.UnitStatus.RESEARCH_0,
                unitType: ISegment4.UnitType.DEFI_PROTOCOL_1,
                revenueShare: 20000,
                emoji: "zzz",
                ui: ui0,
                api: api0,
                pool: SampleDataLib.getUnitPoolSample()
            });
            units[0] = IDAOData.UnitDataInput({unitId: "defi:protocolA", developerUid: ""});
        }

        { // Unit 1: two UI links, one API endpoint
            ISegment4.UnitUiLink[] memory ui1 = new ISegment4.UnitUiLink[](2);
            ui1[0] = ISegment4.UnitUiLink({title: "App", href: "https://unit1.example/app"});
            ui1[1] = ISegment4.UnitUiLink({title: "Docs", href: "https://unit1.example/docs"});

            string[] memory api1 = new string[](1);
            api1[0] = "https://api.unit1.example/";

            emitted[1] = ISegment4.UnitEmitData({
                name: "Service X",
                description: "A SaaS product that provides Y service.",
                status: ISegment4.UnitStatus.BUILDING_3,
                unitType: ISegment4.UnitType.DEFI_PROTOCOL_1,
                revenueShare: 50000,
                emoji: "aaa",
                ui: ui1,
                api: api1,
                pool: SampleDataLib.getUnitPoolSample()
            });
            units[1] = IDAOData.UnitDataInput({unitId: "saas:serviceX", developerUid: ""});
        }

        { // Unit 2: no UI links, empty api array
            ISegment4.UnitUiLink[] memory ui2 = new ISegment4.UnitUiLink[](0);
            string[] memory api2 = new string[](0);

            emitted[2] = ISegment4.UnitEmitData({
                name: "MEV Bot Z",
                description: "zzzz",
                status: ISegment4.UnitStatus.LIVE_4,
                unitType: ISegment4.UnitType.MEV_SEARCHER_2,
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

    function getHostSettings() internal pure returns (IHost.HostSettings memory) {
        return IHost.HostSettings({
            priceDao: 1000,
            fundingFee: 50,
            minNameLength: 1,
            maxNameLength: 20,
            minSymbolLength: 1,
            maxSymbolLength: 7,
            minVePeriod: 14,
            maxVePeriod: 365 * 4,
            minPvPFee: 10,
            maxPvPFee: 100,
            minFunding: 10,
            minFundingDuration: 1 days,
            maxFundingDuration: 180 days,
            minFundingRaise: 0.1e18,
            maxFundingRaise: 1_000_000e18,
            minVestingNameLen: 3,
            maxVestingNameLen: 30,
            minCliff: 7 days,
            minInceptionDuration: DEFAULT_MIN_INCEPTION_DURATION,
            minVestingDuration: 1 days,
            maxVestingDuration: 365 * 4 days
        });
    }

    function getHostChainSettings(
        address hostBridge,
        address dataReader
    ) internal returns (IHost.HostChainSettings memory) {
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);

        return IHost.HostChainSettings({
            exchangeAsset: address(usdc), hostBridge: address(hostBridge), timelock: 30 minutes, dataReader: dataReader
        });
    }

    function prepareFunders(address exchangeAsset, uint totalAmount, uint numFunders) internal returns (EngineLib.Funder[] memory funders) {
        funders = new EngineLib.Funder[](numFunders);

        uint amount = totalAmount;
        for (uint i; i < numFunders; ++i) {
            address funder = address(uint160(i + 1));
            funders[i] = EngineLib.Funder({
                user: funder,
                amount: i == numFunders ? amount : amount / 3
            });
            amount -= funders[i].amount;

            MockERC20(exchangeAsset).mint(funder, funders[i].amount);
        }
    }
}
