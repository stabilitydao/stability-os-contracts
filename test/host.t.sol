// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {SampleDataLib} from "./utils/SampleDataLib.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {MockERC20} from "@solady/../test/utils/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHost} from "../src/interfaces/IHost.sol";
import {IHosted} from "../src/interfaces/IHosted.sol";
import {ISegment4} from "../src/interfaces/ISegment4.sol";
import {IDataReader} from "../src/interfaces/IDataReader.sol";
import {HostLib} from "../src/libs/HostLib.sol";
import {IDAOData} from "../src/interfaces/IDAOData.sol";
import {IAuthority} from "../src/interfaces/IAuthority.sol";
import {ISeedToken} from "../src/interfaces/ISeedToken.sol";
import {IHostCodec} from "../src/interfaces/IHostCodec.sol";
import {Test} from "forge-std/Test.sol";
import {HostUtilsLib} from "./utils/HostUtilsLib.sol";
import {HostEncodingLib} from "../src/libs/HostEncodingLib.sol";
import {AuthorityAccessUtils} from "./scenario/access/AuthorityAccessUtils.sol";
import {HostSetupUtils} from "./scenario/access/HostSetupUtils.sol";

contract HostTest is Test {
    uint public constant FORK_BLOCK = 58135155; // Dec-17-2025 05:45:24 AM +UTC

    string internal constant DAO_SYMBOL = "SPACE";
    string internal constant DAO_NAME = "SpaceSwap";

    string internal constant DAO_SYMBOL2 = "SPACE2";

    address internal immutable MULTISIG;

    constructor() {
        // vm.selectFork(vm.createFork(vm.envString("SONIC_RPC_URL"), FORK_BLOCK));
        MULTISIG = makeAddr("multisig");
    }

    //region ----------------------------------- Unit tests

    function testCreateDAO() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        // -------------------- Prepare test data
        IDAOData.Funding[] memory funding = new IDAOData.Funding[](1);
        funding[0] = HostUtilsLib.generateSeedFunding(
            HostUtilsLib.DEFAULT_SEED_DELAY,
            HostUtilsLib.DEFAULT_SEED_DURATION,
            HostUtilsLib.DEFAULT_SEED_MIN_RAISE,
            HostUtilsLib.DEFAULT_SEED_MAX_RAISE
        );

        IDAOData.Activity[] memory activity = new IDAOData.Activity[](1);
        activity[0] = IDAOData.Activity.DEFI_PROTOCOL_OPERATOR_0;

        IDAOData.DaoParameters memory params = HostUtilsLib.generateDaoParams(365, 100);
        {
            address exchangeAsset = host.getChainSettings().exchangeAsset;
            uint amount = host.getSettings().priceDao;

            deal(exchangeAsset, address(this), amount * 3);

            // user doesn't pay for creation DAO - ERC20InsufficientAllowance
            vm.expectRevert();
            host.createDAO(DAO_NAME, DAO_SYMBOL, activity, params, funding);

            IERC20(exchangeAsset).approve(address(host), amount * 3);

            host.createDAO(DAO_NAME, DAO_SYMBOL, activity, params, funding);
            assertEq(IERC20(exchangeAsset).balanceOf(address(this)), amount * 2, "testCreateDAO - balance after");
        }

        IDAOData.DaoData memory dao = IDataReader(host.getChainSettings().dataReader).getDAO(DAO_SYMBOL);
        assertEq(dao.name, DAO_NAME, "expected name");
        // todo assertEq(os.eventsCount(), 1);

        // -------------------- bad name length
        _dealAndApprove(host);

        vm.expectRevert(abi.encodeWithSelector(IHost.NameLength.selector, uint(28)));
        host.createDAO("SpaceSwap_000000000000000000", "SPACE2", activity, params, funding);

        // -------------------- bad symbol length
        vm.expectRevert(abi.encodeWithSelector(IHost.SymbolLength.selector, uint(9)));
        host.createDAO("SpaceSwap", "SPACESWAP", activity, params, funding);

        // -------------------- not unique symbol
        vm.expectRevert(abi.encodeWithSelector(IHost.SymbolNotUnique.selector, "SPACE"));
        host.createDAO("SpaceSwap", "SPACE", activity, params, funding);

        { // -------------------- bad vePeriod
            IDAOData.DaoParameters memory paramsBadVe = HostUtilsLib.generateDaoParams(
                365 * 5,
                /* 1825 */
                100
            );
            vm.expectRevert(abi.encodeWithSelector(IHost.VePeriod.selector, uint(1825)));
            host.createDAO("SpaceSwap", "SPACE1", activity, paramsBadVe, funding);
        }

        { // -------------------- bad pvpFee
            IDAOData.DaoParameters memory paramsBadPvP = HostUtilsLib.generateDaoParams(365, 101);
            vm.expectRevert(abi.encodeWithSelector(IHost.PvPFee.selector, uint(101)));
            host.createDAO("SpaceSwap", "SPACE1", activity, paramsBadPvP, funding);
        }

        { // -------------------- no funding
            IDAOData.Funding[] memory emptyFunding = new IDAOData.Funding[](0);
            vm.expectRevert(IHost.NeedFunding.selector);
            host.createDAO("SpaceSwap", "SPACE1", activity, params, emptyFunding);
        }
    }

    function testAddLiveDAO() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        // todo only verifier

        _dealAndApprove(host);
        IDAOData.DaoDataInput memory daoOrigin = HostUtilsLib.createTestDaoData();

        _dealAndApprove(host, MULTISIG);

        bytes memory payload = _encode(daoOrigin);
        vm.prank(MULTISIG);
        host.updateByAdmin(IHost.AdminUpdateActions.ADD_LIVE_DAO_0, payload);

        IDAOData.DaoData memory readDao = IDataReader(host.getChainSettings().dataReader).getDAO(daoOrigin.symbol);

        _assertDaoEqual(daoOrigin, readDao);
    }

    function testAddLiveDaoBadPaths() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IDAOData.DaoDataInput memory daoOrigin = HostUtilsLib.createTestDaoData();
        bytes memory payload = _encode(daoOrigin);

        // -------------------- success - check balances
        {
            address exchangeAsset = host.getChainSettings().exchangeAsset;
            uint amount = host.getSettings().priceDao;

            deal(exchangeAsset, MULTISIG, amount * 3);

            // user doesn't pay for creation DAO - ERC20InsufficientAllowance
            vm.expectRevert();
            vm.prank(MULTISIG);
            host.updateByAdmin(IHost.AdminUpdateActions.ADD_LIVE_DAO_0, payload);

            vm.prank(MULTISIG);
            IERC20(exchangeAsset).approve(address(host), amount * 3);

            vm.prank(MULTISIG);
            host.updateByAdmin(IHost.AdminUpdateActions.ADD_LIVE_DAO_0, payload);

            assertEq(IERC20(exchangeAsset).balanceOf(MULTISIG), amount * 2, "balance after 1st dao");
        }

        // -------------------- not unique symbol
        vm.expectRevert(abi.encodeWithSelector(IHost.SymbolNotUnique.selector, "TESTDAO"));
        vm.prank(MULTISIG);
        host.updateByAdmin(IHost.AdminUpdateActions.ADD_LIVE_DAO_0, payload);

        // -------------------- only verifier (restricted)
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        host.updateByAdmin(IHost.AdminUpdateActions.ADD_LIVE_DAO_0, payload);

        // -------------------- todo validation
    }

    function testSetPriceDao() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        IDAOData.Funding[] memory funding = new IDAOData.Funding[](1);
        funding[0] = HostUtilsLib.generateSeedFunding(
            HostUtilsLib.DEFAULT_SEED_DELAY,
            HostUtilsLib.DEFAULT_SEED_DURATION,
            HostUtilsLib.DEFAULT_SEED_MIN_RAISE,
            HostUtilsLib.DEFAULT_SEED_MAX_RAISE
        );

        IDAOData.Activity[] memory activity = new IDAOData.Activity[](1);
        activity[0] = IDAOData.Activity.DEFI_PROTOCOL_OPERATOR_0;

        IDAOData.DaoParameters memory params = HostUtilsLib.generateDaoParams(365, 100);

        // ----------------------------- Set exchange asset to zero
        {
            IHost.HostChainSettings memory cs = host.getChainSettings();
            cs.exchangeAsset = address(0);

            vm.prank(MULTISIG);
            host.setChainSettings(cs);
        }

        // ----------------------------- Set priceDao to 0
        {
            IHost.HostSettings memory st = host.getSettings();
            st.priceDao = 0;

            vm.prank(MULTISIG);
            host.setSettings(st);
        }

        // ----------------------------- create first (host) dao
        address exchangeAsset = host.getChainSettings().exchangeAsset;

        host.createDAO(DAO_NAME, DAO_SYMBOL, activity, params, funding);
        assertEq(
            host.unitBalance(DAO_SYMBOL, exchangeAsset, HostLib.HOST_UNIT), 0, "no creation fee was paid for first dao"
        );

        // ----------------------------- create second-dao
        host.createDAO("name2", "SYMBOL2", activity, params, funding);
        assertEq(
            host.unitBalance(DAO_SYMBOL, exchangeAsset, HostLib.HOST_UNIT), 0, "no creation fee was paid for second dao"
        );

        // ----------------------------- Bad paths: Set priceDao to NOT zero
        {
            IHost.HostSettings memory st = host.getSettings();
            st.priceDao = 1;

            vm.prank(MULTISIG);
            host.setSettings(st);
        }

        vm.expectRevert(IHost.IncorrectConfiguration.selector); // exchange asset cannot be zero
        host.createDAO("name3", "SYMBOL3", activity, params, funding);
    }

    //endregion ----------------------------------- Unit tests

    //region ----------------------------------- Revenue and whitelist
    function testRevenue_CreateTwoDaoExchangeAssetNotWhitelisted_PricesArePaidForDaoCreation() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        // IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);

        address exchangeAsset = host.getChainSettings().exchangeAsset;
        uint amount = host.getSettings().priceDao;

        // ------------------------------ create first (host) dao
        _createDAO(host, DAO_SYMBOL);
        assertEq(
            host.unitBalance(DAO_SYMBOL, exchangeAsset, HostLib.HOST_UNIT),
            amount,
            "host dao paid creation fee to itself"
        );
        assertEq(IERC20(exchangeAsset).balanceOf(address(this)), 0, "user has paid for creation of the first dao");
        assertEq(IERC20(exchangeAsset).balanceOf(address(host)), amount, "creation fee is on balance of the host");

        // ------------------------------ create second dao
        _createDAO(host, DAO_SYMBOL2);

        assertEq(
            host.unitBalance(DAO_SYMBOL, exchangeAsset, HostLib.HOST_UNIT),
            amount * 2,
            "second dao paid creation fee to host dao"
        );
        assertEq(
            host.unitBalance(DAO_SYMBOL2, exchangeAsset, HostLib.HOST_UNIT),
            0,
            "second dao has not received any fees yet"
        );
        assertEq(IERC20(exchangeAsset).balanceOf(address(this)), 0, "user has paid for creation of the second dao");
        assertEq(
            IERC20(exchangeAsset).balanceOf(address(host)), amount * 2, "both creation fees are on balance of the host"
        );
    }

    function testRevenue_PayToRegisteredUnitInExchangeAsset_Success() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);

        // ------------------------------ create host dao
        _createDAO(host, DAO_SYMBOL);

        address exchangeAsset = host.getChainSettings().exchangeAsset;

        // ------------------------------ setup whitelisted assets
        IAuthority authority = AuthorityAccessUtils.getAuthority(host);
        console.log("multisig", MULTISIG);
        console.log("msg.sender", msg.sender);

        vm.startPrank(MULTISIG);
        AuthorityAccessUtils.setRestrictedAccess(
            authority, address(this), 555, address(host), IHost.whitelistAssets.selector
        );
        vm.stopPrank();

        HostSetupUtils.whitelistAsset(vm, address(this), host, address(exchangeAsset));

        // ----------------------------- pay to second dao to registered unit
        {
            (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) =
                SampleDataLib.getUnitsThree();

            host.updateDAO(
                DAO_SYMBOL,
                uint16(IDAOData.DAOAction.UPDATE_UNITS_3),
                codec.encode(units, codec.PAYLOAD_API_VERSION()),
                codec.encode(metas, codec.PAYLOAD_API_VERSION())
            );

            deal(exchangeAsset, address(this), 1e18);
            IERC20(exchangeAsset).approve(address(host), 1e18);
            host.revenue(DAO_SYMBOL, units[0].unitId, exchangeAsset, 1e18);

            assertEq(
                host.unitBalance(DAO_SYMBOL, exchangeAsset, units[0].unitId), 1e18, "second dao received the payment"
            );
        }
    }

    function testRevenue_PayToRegisteredUnitInNotExchangeAsset_Success() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);

        // ------------------------------ create host dao
        _createDAO(host, DAO_SYMBOL);

        // ------------------------------ setup whitelisted assets
        IAuthority authority = AuthorityAccessUtils.getAuthority(host);
        vm.startPrank(MULTISIG);
        AuthorityAccessUtils.setRestrictedAccess(
            authority, address(this), 555, address(host), IHost.whitelistAssets.selector
        );
        vm.stopPrank();
        address mockAsset = address(new MockERC20("Mock", "MOCK", 18));

        HostSetupUtils.whitelistAsset(vm, address(this), host, mockAsset);

        // ----------------------------- pay to second dao to registered unit
        {
            (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) =
                SampleDataLib.getUnitsThree();

            host.updateDAO(
                DAO_SYMBOL,
                uint16(IDAOData.DAOAction.UPDATE_UNITS_3),
                codec.encode(units, codec.PAYLOAD_API_VERSION()),
                codec.encode(metas, codec.PAYLOAD_API_VERSION())
            );

            deal(mockAsset, address(this), 1e18);
            IERC20(mockAsset).approve(address(host), 1e18);
            host.revenue(DAO_SYMBOL, units[0].unitId, mockAsset, 1e18);

            assertEq(host.unitBalance(DAO_SYMBOL, mockAsset, units[0].unitId), 1e18, "second dao received the payment");
        }
    }

    function testRevenue_PayToUnRegisteredUnits_Revert() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        // IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);

        // ------------------------------ create host dao
        _createDAO(host, DAO_SYMBOL);

        address exchangeAsset = host.getChainSettings().exchangeAsset;

        // ------------------------------ setup whitelisted assets
        IAuthority authority = AuthorityAccessUtils.getAuthority(host);
        vm.startPrank(MULTISIG);
        AuthorityAccessUtils.setRestrictedAccess(
            authority, address(this), 555, address(host), IHost.whitelistAssets.selector
        );
        vm.stopPrank();

        HostSetupUtils.whitelistAsset(vm, address(this), host, address(exchangeAsset));

        // ----------------------------- pay to second dao to NOT-registered unit
        {
            deal(exchangeAsset, address(this), 1e18);
            IERC20(exchangeAsset).approve(address(host), 1e18);

            vm.expectRevert(IHost.UnitNotFound.selector);
            host.revenue(DAO_SYMBOL, "UnknownUnitId", exchangeAsset, 1e18);
        }
    }

    function testRevenue_TryToUseNotWhitelistedAsset_Revert() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);

        _createDAO(host, DAO_SYMBOL);

        address mockAsset = address(new MockERC20("Mock", "MOCK", 18));
        // mockAsset is not whitelisted in the host (!)

        (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) = SampleDataLib.getUnitsThree();

        host.updateDAO(
            DAO_SYMBOL,
            uint16(IDAOData.DAOAction.UPDATE_UNITS_3),
            codec.encode(units, codec.PAYLOAD_API_VERSION()),
            codec.encode(metas, codec.PAYLOAD_API_VERSION())
        );

        deal(mockAsset, address(this), 1e18);

        IERC20(mockAsset).approve(address(host), 1e18);

        vm.expectRevert(IHost.AssetNotWhitelisted.selector);
        host.revenue(DAO_SYMBOL, units[0].unitId, mockAsset, 1e18);
    }

    function testRevenue_ZeroAmount_Revert() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);

        // ------------------------------ create host dao
        _createDAO(host, DAO_SYMBOL);

        // ------------------------------ setup whitelisted assets
        IAuthority authority = AuthorityAccessUtils.getAuthority(host);
        vm.startPrank(MULTISIG);
        AuthorityAccessUtils.setRestrictedAccess(
            authority, address(this), 555, address(host), IHost.whitelistAssets.selector
        );
        vm.stopPrank();
        address mockAsset = address(new MockERC20("Mock", "MOCK", 18));

        HostSetupUtils.whitelistAsset(vm, address(this), host, mockAsset);

        // ----------------------------- pay to second dao to registered unit
        {
            (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) =
                SampleDataLib.getUnitsThree();

            host.updateDAO(
                DAO_SYMBOL,
                uint16(IDAOData.DAOAction.UPDATE_UNITS_3),
                codec.encode(units, codec.PAYLOAD_API_VERSION()),
                codec.encode(metas, codec.PAYLOAD_API_VERSION())
            );

            deal(mockAsset, address(this), 1e18);
            IERC20(mockAsset).approve(address(host), 1e18);

            vm.expectRevert(IHosted.ZeroAmount.selector);
            host.revenue(DAO_SYMBOL, units[0].unitId, mockAsset, 0);
        }
    }

    function testWhitelistAsset_Success() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        IAuthority authority = AuthorityAccessUtils.getAuthority(host);
        vm.startPrank(MULTISIG);
        AuthorityAccessUtils.setRestrictedAccess(
            authority, address(this), 555, address(host), IHost.whitelistAssets.selector
        );
        vm.stopPrank();

        {
            address[] memory assets = new address[](2);
            assets[0] = address(0x123);
            assets[1] = address(0x456);

            assertFalse(host.isAssetWhitelisted(assets[0]), "not whitelisted 0x123");
            assertFalse(host.isAssetWhitelisted(assets[1]), "not whitelisted 0x456");

            host.whitelistAssets(assets, true);

            assertTrue(host.isAssetWhitelisted(assets[0]), "whitelisted 0x123");
            assertTrue(host.isAssetWhitelisted(assets[1]), "whitelisted 0x456");
        }

        {
            address[] memory assets = new address[](1);
            assets[0] = address(0x123);

            host.whitelistAssets(assets, false);

            assertFalse(host.isAssetWhitelisted(assets[0]), "not whitelisted 0x123 again");
            assertTrue(host.isAssetWhitelisted(address(0x456)), "whitelisted 0x456");
        }
    }

    function testWhitelistAsset_NotPermitted_Revert() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        address[] memory assets = new address[](2);
        assets[0] = address(0x123);
        assets[1] = address(0x456);

        vm.expectRevert(); // restricted
        host.whitelistAssets(assets, true);
    }

    //endregion ----------------------------------- Revenue and whitelist

    //region ----------------------------------- Change life phase
    function testChangePhase() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        vm.expectRevert(IHost.IncorrectDao.selector);
        vm.prank(MULTISIG);
        host.changePhase("unknown");
    }

    //endregion ----------------------------------- Change life phase

    //region ----------------------------------- Update dao images
    function testUpdateDaoImagesInstant() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        {
            IDAOData.DaoImages memory images = IDAOData.DaoImages({
                seedToken: "new/images/seed.png", tgeToken: "", token: "", xToken: "", daoToken: ""
            });
            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_IMAGES_0),
                codec.encode(images, codec.PAYLOAD_API_VERSION()),
                ""
            );
        }

        {
            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.images.seedToken, "new/images/seed.png", "seedToken updated");
            assertEq(daoAfter.images.tgeToken, dao.images.tgeToken, "tgeToken unchanged");
            assertEq(daoAfter.images.token, dao.images.token, "token unchanged");
            assertEq(daoAfter.images.xToken, dao.images.xToken, "xToken unchanged");
            assertEq(daoAfter.images.daoToken, dao.images.daoToken, "daoToken unchanged");
        }

        {
            IDAOData.DaoImages memory images = SampleDataLib.getDaoImages();
            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_IMAGES_0),
                codec.encode(images, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.images.seedToken, images.seedToken, "seedToken updated");
            assertEq(daoAfter.images.tgeToken, images.tgeToken, "tgeToken updated");
            assertEq(daoAfter.images.token, images.token, "token updated");
            assertEq(daoAfter.images.xToken, images.xToken, "xToken updated");
            assertEq(daoAfter.images.daoToken, images.daoToken, "daoToken updated");
        }
    }

    // todo phase seed

    // todo bad paths
    //endregion ----------------------------------- Update dao images

    //region ----------------------------------- Update socials
    function testUpdateDaoSocialsWithoutVoting() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _setupAuthority(host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        {
            string[] memory socials = new string[](4);
            socials[0] = "updated-1";
            socials[1] = "2";
            socials[2] = "3";
            socials[3] = "4";

            vm.recordLogs();
            host.updateDAO(dao.symbol, uint16(IDAOData.DAOAction.UPDATE_SOCIALS_1), codec.encode(socials), "");

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host, DAO_SYMBOL);
            IDAOData.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(p.validationRequired, "validation required for socials update");
            assertFalse(p.votingRequired, "voting not required for socials update");
            assertEq(uint(p.status), uint(IDAOData.VotingStatus.VOTING_0), "no voting results");

            IDAOData.DaoData memory daoBefore = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoBefore.socials.length, dao.socials.length, "proposal is not applied without validation");

            vm.prank(MULTISIG);
            host.validateProposal(proposalId, true, payload);

            IDAOData.Proposal memory pAfter = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(pAfter.validationStatus == IDAOData.ValidationStatus.APPROVED_1, "proposal is approved");
            assertEq(
                uint(pAfter.status),
                uint(IDAOData.VotingStatus.VOTING_0),
                "still no voting results (voting is NOT required)"
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.socials.length, 4, "socials length");
            assertEq(daoAfter.socials[0], "updated-1", "socials[0] updated");
            assertEq(daoAfter.socials[1], "2", "socials[1] updated");
            assertEq(daoAfter.socials[2], "3", "socials[2] updated");
            assertEq(daoAfter.socials[3], "4", "socials[3] updated");
        }

        {
            string[] memory socials = new string[](2);
            socials[0] = "1111";
            socials[1] = ""; // (!) empty
            host.updateDAO(dao.symbol, uint16(IDAOData.DAOAction.UPDATE_SOCIALS_1), codec.encode(socials), "");

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());
            bytes32 proposalId = HostUtilsLib.getLastProposalId(host, DAO_SYMBOL);
            IDAOData.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(p.validationRequired, "validation required for socials update");
            assertFalse(p.votingRequired, "voting not required for socials update");

            vm.prank(MULTISIG);
            host.validateProposal(proposalId, true, payload);

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.socials.length, 2, "socials length 2");
            assertEq(daoAfter.socials[0], "1111", "socials[0] updated");
            assertEq(daoAfter.socials[1], "", "socials[1] updated");
        }
    }

    function testUpdateDaoSocialsWithoutVotingBadPaths() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _setupAuthority(host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        // ------------------------------ Create proposal to update socials
        string[] memory socials = SampleDataLib.getSocialsThree();

        vm.recordLogs();
        host.updateDAO(dao.symbol, uint16(IDAOData.DAOAction.UPDATE_SOCIALS_1), codec.encode(socials), "");

        bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());
        bytes32 proposalId = HostUtilsLib.getLastProposalId(host, DAO_SYMBOL);

        {
            IDAOData.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(p.validationStatus == IDAOData.ValidationStatus.NONE_0, "proposal is not validated yet");
            assertEq(
                uint(p.status), uint(IDAOData.VotingStatus.VOTING_0), "no voting results yet (no voting is required)"
            );
        }

        // ------------------------------ Reverts
        /// @dev Voting not required and not allowed
        vm.expectRevert(IHost.VotingNotRequired.selector);
        vm.prank(MULTISIG);
        host.receiveVotingResults(proposalId, true, payload);

        /// @dev User not authorized to validate proposal
        vm.expectRevert();
        vm.prank(address(this));
        host.validateProposal(proposalId, true, payload);

        /// @dev Payload content cannot be changed
        vm.expectRevert(IHost.IncorrectProposalPayload.selector);
        vm.prank(MULTISIG);
        host.validateProposal(proposalId, true, _modifyPayloadByte(payload, payload.length - 2, 0xFF));

        // ------------------------------ Admin rejects proposal
        vm.prank(MULTISIG);
        host.validateProposal(proposalId, false, ""); // payload content is not required if rejected

        IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
        assertEq(daoAfter.socials.length, dao.socials.length, "socials unchanged after rejection");

        {
            IDAOData.Proposal memory pAfter = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(pAfter.validationStatus == IDAOData.ValidationStatus.REJECTED_2, "proposal is rejected");
            assertEq(
                uint(pAfter.status),
                uint(IDAOData.VotingStatus.VOTING_0),
                "no voting results yet (no voting is required)"
            );
        }
    }

    function testUpdateDaoSocialsWithVoting() public {
        // ------------------------------ Create HOST
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _setupAuthority(host);

        // ------------------------------ Create DAO
        _dealAndApprove(host);
        IDAOData.DaoData memory daoData = HostUtilsLib.createAliensDao(vm, host, "ALIENS");

        // ------------------------------ Move to seed phase to enable voting
        _moveDaoToSeedPhase(host, codec, daoData.symbol);
        daoData = IDataReader(host.getChainSettings().dataReader).getDAO(daoData.symbol);

        { // ------------------------------ Mint some tokens to be able to vote
            daoData = IDataReader(host.getChainSettings().dataReader).getDAO(daoData.symbol);
            vm.prank(address(host));
            ISeedToken(daoData.deployments.seedToken).mint(address(this), 1e18);
        }

        // ------------------------------ Update socials with proposal
        string[] memory socials = SampleDataLib.getSocialsThree();

        vm.recordLogs();
        host.updateDAO(daoData.symbol, uint16(IDAOData.DAOAction.UPDATE_SOCIALS_1), codec.encode(socials), "");

        bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());
        bytes32 proposalId = HostUtilsLib.getLastProposalId(host, daoData.symbol);

        // ------------------------------ Check proposal status before validation and voting
        {
            IDAOData.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(p.validationRequired, "validation required for socials update");
            assertTrue(p.votingRequired, "voting required for socials update");
            assertEq(uint(p.validationStatus), uint(IDAOData.ValidationStatus.NONE_0), "no validation yet");
            assertEq(uint(p.status), uint(IDAOData.VotingStatus.VOTING_0), "no voting yet");
        }

        // ------------------------------ Voting before validation not allowed
        vm.expectRevert(IHost.ProposalNotValidated.selector);
        vm.prank(MULTISIG);
        host.receiveVotingResults(proposalId, true, payload);

        // ------------------------------ Admin validates proposal
        vm.prank(MULTISIG);
        host.validateProposal(proposalId, true, payload);

        // ------------------------------ Approved by voting
        {
            uint snapshot = vm.snapshotState();

            /// @dev receiveVotingResults is restricted
            vm.expectRevert();
            vm.prank(address(this));
            host.receiveVotingResults(proposalId, true, payload);

            /// @dev Payload content cannot be changed
            vm.expectRevert(IHost.IncorrectProposalPayload.selector);
            vm.prank(MULTISIG);
            host.receiveVotingResults(proposalId, true, _modifyPayloadByte(payload, payload.length - 1, 0xFF));

            vm.prank(MULTISIG);
            host.receiveVotingResults(proposalId, true, payload);

            IDAOData.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertEq(uint(p.validationStatus), uint(IDAOData.ValidationStatus.APPROVED_1), "validated");
            assertEq(uint(p.status), uint(IDAOData.VotingStatus.APPROVED_1), "approved in voting");

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(daoData.symbol);
            assertEq(daoAfter.socials.length, 3, "socials length");
            assertEq(daoAfter.socials[0], socials[0], "socials[0] updated");
            assertEq(daoAfter.socials[1], socials[1], "socials[1] updated");
            assertEq(daoAfter.socials[2], socials[2], "socials[2] updated");

            vm.revertToState(snapshot);
        }

        // ------------------------------ Rejected by voting
        {
            uint snapshot = vm.snapshotState();

            vm.prank(MULTISIG);
            host.receiveVotingResults(proposalId, false, payload);

            IDAOData.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertEq(uint(p.validationStatus), uint(IDAOData.ValidationStatus.APPROVED_1), "validated");
            assertEq(uint(p.status), uint(IDAOData.VotingStatus.REJECTED_2), "rejected in voting");

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(daoData.symbol);

            assertEq(daoAfter.socials.length, daoData.socials.length, "socials unchanged after rejection");

            vm.revertToState(snapshot);
        }
    }

    //endregion ----------------------------------- Update socials

    //region ----------------------------------- Update units
    function testUpdateUnitsInstant() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        {
            (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) = SampleDataLib.getUnitsTwo();

            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_UNITS_3),
                codec.encode(units, codec.PAYLOAD_API_VERSION()),
                codec.encode(metas, codec.PAYLOAD_API_VERSION())
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.units.length, 2, "units length");
            assertTrue(
                keccak256(abi.encode(units[0].unitId)) == keccak256(abi.encode(daoAfter.units[0].unitId)), "unitId-eq1"
            );
            assertTrue(
                keccak256(abi.encode(units[1].unitId)) == keccak256(abi.encode(daoAfter.units[1].unitId)), "unitId-eq2"
            );
            assertTrue(
                keccak256(abi.encode(units[0].developerUid)) == keccak256(abi.encode(daoAfter.units[0].developerUid)),
                "developerUid-eq1"
            );
            assertTrue(
                keccak256(abi.encode(units[1].developerUid)) == keccak256(abi.encode(daoAfter.units[1].developerUid)),
                "developerUid-eq2"
            );
        }

        {
            (IDAOData.UnitDataInput[] memory units, ISegment4.UnitEmitData[] memory metas) =
                SampleDataLib.getUnitsThree();
            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_UNITS_3),
                codec.encode(units, codec.PAYLOAD_API_VERSION()),
                codec.encode(metas, codec.PAYLOAD_API_VERSION())
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.units.length, 3, "units length");

            assertTrue(
                keccak256(abi.encode(units[0].unitId)) == keccak256(abi.encode(daoAfter.units[0].unitId)),
                "first unit id matches"
            );
        }
    }

    //endregion ----------------------------------- Update units

    //region ----------------------------------- Update funding
    function testUpdateFundingInstant() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        IDAOData.Funding memory seed;
        seed.fundingType = IDAOData.FundingType.SEED_0;
        seed.start = 1 days;
        seed.end = 90 days;
        seed.minRaise = 1e18;
        seed.maxRaise = 100e18;
        seed.raised = 250;
        seed.claim = 1;

        {
            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_FUNDING_4),
                codec.encode(seed, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.funding.length, 1, "funding length");

            IDAOData.Funding memory fundingAfter = daoAfter.funding[0];

            assertEq(uint8(fundingAfter.fundingType), uint8(seed.fundingType));
            assertEq(uint64(fundingAfter.start), uint64(seed.start));
            assertEq(uint64(fundingAfter.end), uint64(seed.end));
            assertEq(fundingAfter.minRaise, seed.minRaise);
            assertEq(fundingAfter.maxRaise, seed.maxRaise);
            assertEq(fundingAfter.raised, seed.raised);
            assertEq(fundingAfter.claim, seed.claim);
        }

        {
            IDAOData.Funding memory tge;
            tge.fundingType = IDAOData.FundingType.TGE_1;
            tge.start = 1 days;
            tge.end = 120 days;
            tge.minRaise = 10003e18;
            tge.maxRaise = 50004e18;
            tge.raised = 2505;
            tge.claim = 16;

            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_FUNDING_4),
                codec.encode(tge, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.funding.length, 2, "funding length");

            IDAOData.Funding memory seed0 = daoAfter.funding[0];
            IDAOData.Funding memory tge1 = daoAfter.funding[1];

            assertEq(uint8(tge1.fundingType), uint8(tge.fundingType), "tge type");
            assertEq(uint64(tge1.start), uint64(tge.start), "tge start");
            assertEq(uint64(tge1.end), uint64(tge.end), "tge end");
            assertEq(tge1.minRaise, tge.minRaise, "tge minRaise");
            assertEq(tge1.maxRaise, tge.maxRaise, "tge maxRaise");
            assertEq(tge1.raised, tge.raised, "tge raised");
            assertEq(tge1.claim, tge.claim, "tge claimed");

            assertEq(uint8(seed0.fundingType), uint8(seed.fundingType), "seed fundingType is unchanged");
            assertEq(uint64(seed0.start), uint64(seed.start), "seed start is unchanged");
            assertEq(uint64(seed0.end), uint64(seed.end), "seed end is unchanged");
            assertEq(seed0.minRaise, seed.minRaise, "seed minRaise is unchanged");
            assertEq(seed0.maxRaise, seed.maxRaise, "seed maxRaise is unchanged");
            assertEq(seed0.raised, seed.raised, "seed raised is unchanged");
            assertEq(seed0.claim, seed.claim, "seed claim is unchanged");
        }
    }

    //endregion ----------------------------------- Update funding

    //region ----------------------------------- Update vesting
    function testUpdateVestingInstant() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        // ------------------------------ set TGE to be able to set vesting
        {
            IDAOData.Funding memory funding = HostUtilsLib.generateTGEFunding();

            vm.recordLogs();
            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_FUNDING_4),
                codec.encode(funding, codec.PAYLOAD_API_VERSION()),
                ""
            );
        }

        {
            IDAOData.Vesting[] memory vesting = new IDAOData.Vesting[](2);
            vesting[0] = IDAOData.Vesting({
                name: "Team",
                description: "team vesting",
                allocation: 10_000,
                start: uint64(block.timestamp + 20 days),
                end: uint64(block.timestamp + 50 days)
            });
            vesting[1] = IDAOData.Vesting({
                name: "Seed",
                description: "seed vesting",
                allocation: 20_000,
                start: uint64(block.timestamp + 30 days),
                end: uint64(block.timestamp + 70 days)
            });

            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_VESTING_5),
                codec.encode(vesting, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.vesting.length, 2, "vesting length");

            assertTrue(_same(daoAfter.vesting[0], vesting[0]), "vesting[0] eq");
            assertTrue(_same(daoAfter.vesting[1], vesting[1]), "vesting[1] eq");
        }

        {
            IDAOData.Vesting[] memory vesting = new IDAOData.Vesting[](1);
            vesting[0] = IDAOData.Vesting({
                name: "Team3",
                description: "team vesting3",
                allocation: 10_003,
                start: uint64(block.timestamp + 33 days),
                end: uint64(block.timestamp + 55 days)
            });

            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_VESTING_5),
                codec.encode(vesting, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.vesting.length, 1, "vesting length 2");

            assertTrue(_same(daoAfter.vesting[0], vesting[0]), "vesting[0] eq");
        }
    }

    //endregion ----------------------------------- Update vesting

    //region ----------------------------------- Update naming
    /// @dev Instant update is not possible. Admin must validate proposal to avoid any collision with other updates
    function testUpdateNamingWith_ValidationNoVoting() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        _setupAuthority(host);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        {
            IDAOData.DaoNames memory naming = IDAOData.DaoNames({name: "New DAO Name", symbol: "NEWDS"});

            bytes memory payload = codec.encode(naming, codec.PAYLOAD_API_VERSION());

            host.updateDAO(dao.symbol, uint16(IDAOData.DAOAction.UPDATE_NAMING_2), payload, "");

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host, dao.symbol);

            vm.prank(MULTISIG);
            host.validateProposal(proposalId, true, payload);

            IDAOData.DaoData memory dao1 = IDataReader(host.getChainSettings().dataReader).getDAO(DAO_SYMBOL);
            IDAOData.DaoData memory dao2 = IDataReader(host.getChainSettings().dataReader).getDAO(naming.symbol);

            assertEq(dao2.uid, dao.uid, "uid is unchanged");
            assertEq(dao1.uid, 0, "old symbol is not used anymore");

            assertEq(dao2.name, naming.name, "name updated");
            assertEq(dao2.deployer, dao.deployer, "deployer wasn't changed");
        }
    }

    function testUpdateNamingWith_ValidationVoting() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        _setupAuthority(host);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        _moveDaoToSeedPhase(host, codec, dao.symbol);

        { // ------------------------------ Mint some tokens to be able to vote
            dao = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            vm.prank(address(host));
            ISeedToken(dao.deployments.seedToken).mint(address(this), 1e18);
        }

        {
            IDAOData.DaoNames memory naming = IDAOData.DaoNames({name: "New DAO Name", symbol: "NEWDS"});

            bytes memory payload = codec.encode(naming, codec.PAYLOAD_API_VERSION());

            host.updateDAO(dao.symbol, uint16(IDAOData.DAOAction.UPDATE_NAMING_2), payload, "");

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host, dao.symbol);

            vm.prank(MULTISIG);
            host.validateProposal(proposalId, true, payload);

            vm.prank(MULTISIG);
            host.receiveVotingResults(proposalId, true, payload);

            IDAOData.DaoData memory dao1 = IDataReader(host.getChainSettings().dataReader).getDAO(DAO_SYMBOL);
            IDAOData.DaoData memory dao2 = IDataReader(host.getChainSettings().dataReader).getDAO(naming.symbol);

            assertEq(dao2.uid, dao.uid, "uid is unchanged");
            assertEq(dao1.uid, 0, "old symbol is not used anymore");

            assertEq(dao2.name, naming.name, "name updated");
            assertEq(dao2.deployer, dao.deployer, "deployer wasn't changed");
        }
    }

    //endregion ----------------------------------- Update naming

    //region ----------------------------------- Update dao parameters
    function testUpdateDaoParametersInstant() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        {
            IDAOData.DaoParameters memory a;
            a.vePeriod = 100;
            a.pvpFee = 10;
            a.minPower = 1000;
            a.ttBribe = 1;
            a.recoveryShare = 2;
            a.proposalThreshold = 50;

            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_DAO_PARAMETERS_6),
                codec.encode(a, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);

            assertEq(keccak256(abi.encode(daoAfter.params)), keccak256(abi.encode(a)), "params");
        }
    }

    function testUpdateDaoChainSettingsInstant() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        {
            IDAOData.DaoChainSettings memory data = IDAOData.DaoChainSettings({bbRate: 100, multisig: address(0)});

            host.updateDAO(
                dao.symbol,
                uint16(IDAOData.DAOAction.UPDATE_DAO_CHAIN_SETTINGS_8),
                codec.encode(data, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);

            assertEq(keccak256(abi.encode(daoAfter.chainSettings)), keccak256(abi.encode(data)), "chain settings");
        }
    }

    function testUpdateDaoChainSettingsProposal() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        _setupAuthority(host);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);

        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);
        _moveDaoToSeedPhase(host, codec, dao.symbol);

        dao = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);

        vm.prank(address(host));
        ISeedToken(dao.deployments.seedToken).mint(address(this), 1e18);

        IDAOData.DaoChainSettings memory data = IDAOData.DaoChainSettings({bbRate: 90, multisig: address(0)});

        bytes memory payload = codec.encode(data, codec.PAYLOAD_API_VERSION());

        host.updateDAO(dao.symbol, uint16(IDAOData.DAOAction.UPDATE_DAO_CHAIN_SETTINGS_8), payload, "");

        bytes32 proposalId = HostUtilsLib.getLastProposalId(host, dao.symbol);

        vm.prank(MULTISIG);
        host.receiveVotingResults(proposalId, true, payload);

        IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);

        assertEq(keccak256(abi.encode(daoAfter.chainSettings)), keccak256(abi.encode(data)), "chain settings");
    }

    //endregion ----------------------------------- Update dao parameters

    //region ----------------------------------- Internal logic
    function _createDAO(IHost host, string memory symbol_) internal {
        IDAOData.Funding[] memory funding = new IDAOData.Funding[](1);
        funding[0] = HostUtilsLib.generateSeedFunding(
            HostUtilsLib.DEFAULT_SEED_DELAY,
            HostUtilsLib.DEFAULT_SEED_DURATION,
            HostUtilsLib.DEFAULT_SEED_MIN_RAISE,
            HostUtilsLib.DEFAULT_SEED_MAX_RAISE
        );

        IDAOData.Activity[] memory activity = new IDAOData.Activity[](1);
        activity[0] = IDAOData.Activity.DEFI_PROTOCOL_OPERATOR_0;

        IDAOData.DaoParameters memory params = HostUtilsLib.generateDaoParams(365, 100);

        // ----------------------------- prepare to pay creation fee
        address exchangeAsset = host.getChainSettings().exchangeAsset;
        uint amount = host.getSettings().priceDao;

        deal(exchangeAsset, address(this), amount);

        IERC20(exchangeAsset).approve(address(host), amount);

        host.createDAO(DAO_NAME, symbol_, activity, params, funding);
    }

    function _same(IDAOData.Vesting memory a, IDAOData.Vesting memory b) internal pure returns (bool) {
        return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
    }

    function _assertDaoEqual(IDAOData.DaoDataInput memory expected, IDAOData.DaoData memory actual) internal pure {
        // basic fields
        assertEq(uint(uint8(expected.phase)), uint(uint8(actual.phase)), "phase");
        assertEq(expected.symbol, actual.symbol, "symbol");
        assertEq(expected.name, actual.name, "name");
        assertEq(expected.deployer, actual.deployer, "deployer");

        // socials
        assertEq(expected.socials.length, actual.socials.length, "socials.length");
        for (uint i = 0; i < expected.socials.length; i++) {
            assertEq(expected.socials[i], actual.socials[i], "socials[i]");
        }

        // activity
        assertEq(expected.activity.length, actual.activity.length, "activity.length");
        for (uint i = 0; i < expected.activity.length; i++) {
            assertEq(uint(uint8(expected.activity[i])), uint(uint8(actual.activity[i])), "activity[i]");
        }

        // images
        assertEq(expected.images.seedToken, actual.images.seedToken, "images.seedToken");
        assertEq(expected.images.tgeToken, actual.images.tgeToken, "images.tgeToken");
        assertEq(expected.images.token, actual.images.token, "images.token");
        assertEq(expected.images.xToken, actual.images.xToken, "images.xToken");
        assertEq(expected.images.daoToken, actual.images.daoToken, "images.daoToken");

        // deployments
        assertEq(expected.deployments.seedToken, actual.deployments.seedToken, "deploy.seedToken");
        assertEq(expected.deployments.tgeToken, actual.deployments.tgeToken, "deploy.tgeToken");
        assertEq(expected.deployments.token, actual.deployments.token, "deploy.token");
        assertEq(expected.deployments.xToken, actual.deployments.xToken, "deploy.xToken");
        assertEq(expected.deployments.staking, actual.deployments.staking, "deploy.staking");
        assertEq(expected.deployments.daoToken, actual.deployments.daoToken, "deploy.daoToken");
        assertEq(expected.deployments.revenueRouter, actual.deployments.revenueRouter, "deploy.revenueRouter");
        assertEq(expected.deployments.recovery, actual.deployments.recovery, "deploy.recovery");
        assertTrue(
            keccak256(abi.encode(expected.deployments.vesting)) == keccak256(abi.encode(actual.deployments.vesting)),
            "deploy.vesting hash"
        );
        assertEq(expected.deployments.tokenBridge, actual.deployments.tokenBridge, "deploy.tokenBridge");
        assertEq(expected.deployments.xTokenBridge, actual.deployments.xTokenBridge, "deploy.xTokenBridge");
        assertEq(expected.deployments.daoTokenBridge, actual.deployments.daoTokenBridge, "deploy.daoTokenBridge");

        // params
        assertEq(expected.params.vePeriod, actual.params.vePeriod, "params.vePeriod");
        assertEq(expected.params.pvpFee, actual.params.pvpFee, "params.pvpFee");
        assertEq(expected.params.minPower, actual.params.minPower, "params.minPower");
        assertEq(expected.params.ttBribe, actual.params.ttBribe, "params.ttBribe");
        assertEq(expected.params.recoveryShare, actual.params.recoveryShare, "params.recoveryShare");
        assertEq(expected.params.proposalThreshold, actual.params.proposalThreshold, "params.proposalThreshold");

        // units
        // todo
        //        assertEq(expected.units.length, actual.units.length, "units.length");
        //        for (uint i = 0; i < expected.units.length; i++) {
        //            IDAOData.UnitDataInput memory eu = expected.units[i];
        //            IDAOData.UnitDataInput memory au = actual.units[i];
        //
        //            assertEq(eu.unitId, au.unitId, "unit.unitId");
        //            assertEq(eu.name, au.name, "unit.name");
        //            assertEq(uint(uint8(eu.status)), uint(uint8(au.status)), "unit.status");
        //            assertEq(eu.unitType, au.unitType, "unit.unitType");
        //            assertEq(eu.revenueShare, au.revenueShare, "unit.revenueShare");
        //            assertEq(eu.emoji, au.emoji, "unit.emoji");
        //
        //            // ui links
        //            assertEq(eu.ui.length, au.ui.length, "unit.ui.length");
        //            for (uint j = 0; j < eu.ui.length; j++) {
        //                assertEq(eu.ui[j].title, au.ui[j].title, "unit.ui.label");
        //                assertEq(eu.ui[j].href, au.ui[j].href, "unit.ui.url");
        //            }
        //
        //            // api endpoints
        //            assertEq(eu.api.length, au.api.length, "unit.api.length");
        //            for (uint j = 0; j < eu.api.length; j++) {
        //                assertEq(eu.api[j], au.api[j], "unit.api");
        //            }
        //        }

        // tokenomics: funding
        assertEq(expected.funding.length, actual.funding.length, "tokenomics.funding.length");
        for (uint i = 0; i < expected.funding.length; i++) {
            IDAOData.Funding memory ef = expected.funding[i];
            IDAOData.Funding memory af = actual.funding[i];

            assertEq(uint(uint8(ef.fundingType)), uint(uint8(af.fundingType)), "funding.fundingType");
            assertEq(ef.start, af.start, "funding.start");
            assertEq(ef.end, af.end, "funding.end");
            assertEq(ef.minRaise, af.minRaise, "funding.minRaise");
            assertEq(ef.maxRaise, af.maxRaise, "funding.maxRaise");
            assertEq(ef.raised, af.raised, "funding.raised");
            assertEq(ef.claim, af.claim, "funding.claim");
        }

        // vesting
        assertEq(expected.vesting.length, actual.vesting.length, "tokenomics.vesting.length");
        for (uint i = 0; i < expected.vesting.length; i++) {
            IDAOData.Vesting memory ev = expected.vesting[i];
            IDAOData.Vesting memory av = actual.vesting[i];

            assertEq(ev.name, av.name, "vesting.name");
            assertEq(ev.description, av.description, "vesting.description");
            assertEq(ev.allocation, av.allocation, "vesting.allocation");
            assertEq(ev.start, av.start, "vesting.start");
            assertEq(ev.end, av.end, "vesting.end");
        }

        // initialChain
        // todo assertEq(expected.initialChain, actual.initialChain, "tokenomics.initialChain");
    }

    /// @notice user should pay for DAO-creation
    function _dealAndApprove(IHost os_, address user) internal {
        address exchangeAsset = os_.getChainSettings().exchangeAsset;
        uint amount = os_.getSettings().priceDao;

        deal(exchangeAsset, user, amount);

        vm.prank(user);
        IERC20(exchangeAsset).approve(address(os_), amount);
    }

    function _dealAndApprove(IHost os_) internal {
        _dealAndApprove(os_, address(this));
    }

    function _setupAuthority(IHost host) internal {
        vm.startPrank(MULTISIG);
        AuthorityAccessUtils.setupHostMultisigAccess(host, MULTISIG);
        AuthorityAccessUtils.setupHostAsAuthorityAdmin(host, MULTISIG);
        vm.stopPrank();
    }

    function _moveDaoToSeedPhase(IHost host_, IHostCodec codec_, string memory symbol) internal {
        IDAOData.DaoData memory daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(symbol);

        {
            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertGe(tasks.length, 2, "at least 2 unsolved tasks");
            //HostUtilsLib.printTasks(tasks);

            // deployer drew token logotypes
            IDAOData.DaoImages memory images = SampleDataLib.getDaoImages();
            host_.updateDAO(
                daoData.symbol,
                uint16(IDAOData.DAOAction.UPDATE_IMAGES_0),
                codec_.encode(images, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            // units project
            (IDAOData.UnitDataInput[] memory units0, ISegment4.UnitEmitData[] memory metas0) =
                SampleDataLib.getUnitsSingle();

            host_.updateDAO(
                daoData.symbol,
                uint16(IDAOData.DAOAction.UPDATE_UNITS_3),
                codec_.encode(units0, codec_.PAYLOAD_API_VERSION()),
                codec_.encode(metas0, codec_.PAYLOAD_API_VERSION())
            );

            // registered socials
            string[] memory socials = SampleDataLib.getSocialsThree();

            vm.recordLogs();
            host_.updateDAO(daoData.symbol, uint16(IDAOData.DAOAction.UPDATE_SOCIALS_1), codec_.encode(socials), "");

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());
            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);

            vm.prank(MULTISIG);
            host_.validateProposal(proposalId, true, payload);
        }

        // ------------------------------ fix funding
        {
            IDAOData.Funding memory funding = IDAOData.Funding({
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
                uint16(IDAOData.DAOAction.UPDATE_FUNDING_4),
                codec_.encode(funding, codec_.PAYLOAD_API_VERSION()),
                ""
            );
        }

        // ------------------------------ change phase to inception
        host_.changePhase(daoData.symbol);
        skip(7 days);

        // ------------------------------ change phase to seed
        skip(24 days);
        host_.changePhase(daoData.symbol);

        // ------------------------------ refresh daoData
        daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);
    }

    /// @dev A function to modify i-th byte in payload for test purpose
    function _modifyPayloadByte(bytes memory payload, uint index, bytes1 value) internal pure returns (bytes memory) {
        bytes memory out = new bytes(payload.length);
        for (uint i; i < payload.length; i++) {
            out[i] = payload[i];
        }
        out[index] = value;
        return out;
    }

    /// @dev Extracted from HostCodec to reduce HostCodec size
    function _encode(IDAOData.DaoDataInput memory dao) internal pure returns (bytes memory payload) {
        return HostEncodingLib.encodeDaoDataInput(dao);
    }

    function _decodeDaoDataInput(bytes memory payload) internal pure returns (IDAOData.DaoDataInput memory dao) {
        return HostEncodingLib.decodeDaoDataInput(payload);
    }
    //endregion ----------------------------------- Internal logic

}
