// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SampleDataLib} from "./utils/SampleDataLib.sol";
import {HostUtilsLib} from "./utils/HostUtilsLib.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IAuthority} from "../src/interfaces/IAuthority.sol";
import {IDAOData} from "../src/interfaces/IDAOData.sol";
import {ISegment4} from "../src/interfaces/ISegment4.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHostCodec} from "../src/interfaces/IHostCodec.sol";
import {IDataReader} from "../src/interfaces/IDataReader.sol";
import {IHost} from "../src/interfaces/IHost.sol";
import {IProxyFactory} from "../src/interfaces/IProxyFactory.sol";
import {ITokenomics} from "../src/interfaces/ITokenomics.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AuthorityAccessUtils} from "./intents/access/AuthorityAccessUtils.sol";

contract DataReaderTest is Test {
    string internal constant DAO_SYMBOL = "ALIENS";

    address internal constant FIRST_SEEDER = address(0x11);
    address internal constant SECOND_SEEDER = address(0x22);
    address internal constant THIRD_SEEDER = address(0x33);

    address internal immutable MULTISIG;

    constructor() {
        MULTISIG = makeAddr("multisig");
    }

    function testReadDaoWithFullFilledData() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = _createHostCodec(host);

        AuthorityAccessUtils.setupHostAsAuthorityAdmin(vm, host, MULTISIG);

        lifeCycleUpToTGE(host, codec);

        IDataReader dataReader = IDataReader(host.getChainSettings().dataReader);
        IDAOData.DaoData memory daoData = dataReader.getDAO(DAO_SYMBOL);
        assertEq(daoData.symbol, DAO_SYMBOL, "dao symbol");
    }

    //region ------------------------------ Internal logic
    function lifeCycleUpToTGE(IHost host_, IHostCodec codec_) internal {
        address asset = host_.getChainSettings().exchangeAsset;
        IDataReader dataReader = IDataReader(host_.getChainSettings().dataReader);

        // ------------------------------ Create DAO
        _dealAndApprove(host_);
        IDAOData.DaoData memory daoData = HostUtilsLib.createAliensDao(vm, host_, DAO_SYMBOL);

        // ------------------------------ solve required tasks
        {
            skip(7 days);

            // deployer drew token logotypes
            ITokenomics.DaoImages memory images = SampleDataLib.getDaoImages();
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_IMAGES_0),
                codec_.encode(images, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            // units project
            (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) = SampleDataLib.getUnitsTwo();

            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
                codec_.encode(units, codec_.PAYLOAD_API_VERSION()),
                codec_.encode(metas, codec_.PAYLOAD_API_VERSION())
            );

            // registered socials
            string[] memory socials = SampleDataLib.getSocialsThree();

            HostUtilsLib.updateSocialsWithValidation(vm, MULTISIG, host_, codec_, daoData.symbol, socials);

            ITokenomics.Funding memory funding = ITokenomics.Funding({
                fundingType: daoData.funding[0].fundingType,
                start: daoData.funding[0].start,
                end: daoData.funding[0].end,
                minRaise: daoData.funding[0].minRaise,
                maxRaise: 90_000e18,
                raised: daoData.funding[0].raised,
                claim: daoData.funding[0].claim
            });

            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4),
                codec_.encode(funding, codec_.PAYLOAD_API_VERSION()),
                ""
            );
        }

        // ------------------------------ set SALT for seed token
        address predictedSeedAddress;
        {
            IProxyFactory proxyFactory = IProxyFactory(_getAuthority(host_).PROXY_FACTORY());

            bytes32[] memory salts = new bytes32[](1);
            salts[0] = "0x0101";

            predictedSeedAddress = IProxyFactory(proxyFactory).predictAddress(salts[0]);

            uint16[] memory indices = new uint16[](1);
            indices[0] = uint16(ITokenomics.ContractIndices.SEED_TOKEN_1);

            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_SALT_7),
                codec_.encode(indices, salts, codec_.PAYLOAD_API_VERSION()),
                ""
            );
        }

        // ------------------------------ change phase to inception
        host_.changePhase(daoData.symbol);

        // ------------------------------ change phase to seed
        {
            skip(24 days);

            host_.changePhase(daoData.symbol);
        }

        // ------------------------------ SEED started. First seeder
        {
            deal(asset, FIRST_SEEDER, 5000e18);

            vm.prank(FIRST_SEEDER);
            IERC20(asset).approve(address(host_), 5000e18);

            vm.prank(FIRST_SEEDER);
            host_.fund(daoData.symbol, 1000e18);
        }

        // ------------------------------ set SALT for tge token through proposal
        address predictedTgeAddress;
        {
            bytes memory input;
            {
                IProxyFactory proxyFactory = IProxyFactory(_getAuthority(host_).PROXY_FACTORY());

                bytes32[] memory salts = new bytes32[](2);
                salts[0] = "0x0101";
                salts[1] = "0x0202";

                predictedTgeAddress = IProxyFactory(proxyFactory).predictAddress(salts[0]);

                uint16[] memory indices = new uint16[](2);
                indices[0] = uint16(ITokenomics.ContractIndices.SEED_TOKEN_1); // we can update seed token salt even if the token is already created
                indices[1] = uint16(ITokenomics.ContractIndices.TGE_TOKEN_2);

                input = codec_.encode(indices, salts, codec_.PAYLOAD_API_VERSION());
            }

            vm.recordLogs();
            host_.updateDAO(daoData.symbol, uint16(ITokenomics.DAOAction.UPDATE_SALT_7), input, "");

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);

            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);
        }

        // ------------------------------ Second seeder
        {
            deal(asset, SECOND_SEEDER, 10000e18);

            vm.prank(SECOND_SEEDER);
            IERC20(asset).approve(address(host_), type(uint).max);

            vm.prank(SECOND_SEEDER);
            host_.fund(daoData.symbol, 10000e18);

            deal(asset, SECOND_SEEDER, 100000000e18);
        }

        // ------------------------------ DEVELOPMENT phase started (SEED succeed), refresh daoData
        {
            skip(100 days);

            host_.changePhase(daoData.symbol);
            daoData = dataReader.getDAO(daoData.symbol);
        }

        // ------------------------------ fill TGE funding, refresh daoData
        {
            ITokenomics.Funding memory funding = HostUtilsLib.generateTGEFunding();

            vm.recordLogs();
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4),
                codec_.encode(funding, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);

            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);

            daoData = dataReader.getDAO(daoData.symbol);
        }

        // ------------------------------ fix units
        {
            // put some amount on unit balance - it means that the unit is "live"
            address exchangeAsset = host_.getChainSettings().exchangeAsset;
            deal(exchangeAsset, address(this), 1000e18);
            IERC20(exchangeAsset).approve(address(host_), 1000e18);
            host_.revenue(daoData.symbol, daoData.units[0].unitId, exchangeAsset, 1000e18);
        }

        // ------------------------------ add vesting
        {
            uint fundingIndex = HostUtilsLib.getFundingIndex(daoData, ITokenomics.FundingType.TGE_1);
            ITokenomics.Funding memory tgeFunding = daoData.funding[fundingIndex];

            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = HostUtilsLib.generateVesting("Development", tgeFunding.end);

            vm.recordLogs();
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_VESTING_5),
                codec_.encode(vesting, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);
            vm.prank(MULTISIG);
            host_.receiveVotingResults(proposalId, true, payload);
        }

        // ------------------------------ TGE phase started (DEVELOPMENT done), refresh daoData
        {
            skip(180 days);

            host_.changePhase(daoData.symbol);
            daoData = dataReader.getDAO(daoData.symbol);

            assertEq(uint(daoData.phase), uint(ITokenomics.LifecyclePhase.TGE_5), "phase should be TGE");
            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertGt(tasks.length, 0, "there are unsolved tasks on TGE phase");
        }

        assertEq(IERC20Metadata(daoData.deployments.tgeToken).name(), "Aliens Community PRESALE", "tge name");
        assertEq(IERC20Metadata(daoData.deployments.tgeToken).symbol(), "saleALIENS", "tge symbol");

        // HostUtilsLib.printDaoData(daoData);
    }

    //endregion ------------------------------ Internal logic

    //region ------------------------------ Utils
    /// @notice user should pay for DAO-creation
    function _dealAndApprove(IHost os_) internal {
        address exchangeAsset = os_.getChainSettings().exchangeAsset;
        uint amount = os_.getSettings().priceDao;
        deal(exchangeAsset, address(this), amount);
        IERC20(exchangeAsset).approve(address(os_), amount);
    }

    function _getAuthority(IHost host) internal view returns (IAuthority) {
        return IAuthority(IAccessManaged(address(host)).authority());
    }

    function _keepConsoleInImport() internal pure {
        console.log("hide warning about removing console from imports");
    }

    function _createHostCodec(IHost host) internal returns (IHostCodec) {
        return HostUtilsLib.createHostCodec(vm, MULTISIG, host);
    }

    //endregion ------------------------------ Utils
}
