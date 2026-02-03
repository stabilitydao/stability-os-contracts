// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHost} from "../src/interfaces/IHost.sol";
import {IDAOData} from "../src/interfaces/IDAOData.sol";
import {IDAOMetadata} from "../src/interfaces/IDAOMetadata.sol";
import {IDataReader} from "../src/interfaces/IDataReader.sol";
import {HostLib} from "../src/libs/HostLib.sol";
import {ITokenomics} from "../src/interfaces/ITokenomics.sol";
import {IHostCodec} from "../src/interfaces/IHostCodec.sol";
import {Test} from "forge-std/Test.sol";
import {HostUtilsLib} from "./utils/HostUtilsLib.sol";
import {HostEncodingLib} from "../src/libs/HostEncodingLib.sol";

contract HostTest is Test {
    uint public constant FORK_BLOCK = 58135155; // Dec-17-2025 05:45:24 AM +UTC

    string internal constant DAO_SYMBOL = "SPACE";
    string internal constant DAO_NAME = "SpaceSwap";

    address internal immutable MULTISIG;

    constructor() {
        // vm.selectFork(vm.createFork(vm.envString("SONIC_RPC_URL"), FORK_BLOCK));
        MULTISIG = makeAddr("multisig");
    }

    //region ----------------------------------- Unit tests

    function testCreateDAO() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        // -------------------- Prepare test data
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = HostUtilsLib.generateSeedFunding(
            HostUtilsLib.DEFAULT_SEED_DELAY,
            HostUtilsLib.DEFAULT_SEED_DURATION,
            HostUtilsLib.DEFAULT_SEED_MIN_RAISE,
            HostUtilsLib.DEFAULT_SEED_MAX_RAISE
        );

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = HostUtilsLib.generateDaoParams(365, 100);
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
            ITokenomics.DaoParameters memory paramsBadVe = HostUtilsLib.generateDaoParams(
                365 * 5,
                /* 1825 */
                100
            );
            vm.expectRevert(abi.encodeWithSelector(IHost.VePeriod.selector, uint(1825)));
            host.createDAO("SpaceSwap", "SPACE1", activity, paramsBadVe, funding);
        }

        { // -------------------- bad pvpFee
            ITokenomics.DaoParameters memory paramsBadPvP = HostUtilsLib.generateDaoParams(365, 101);
            vm.expectRevert(abi.encodeWithSelector(IHost.PvPFee.selector, uint(101)));
            host.createDAO("SpaceSwap", "SPACE1", activity, paramsBadPvP, funding);
        }

        { // -------------------- no funding
            ITokenomics.Funding[] memory emptyFunding = new ITokenomics.Funding[](0);
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
        host.updateRestricted(uint(IHost.RestrictedUpdates.ADD_LIVE_DAO_0), payload);

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
            host.updateRestricted(uint(IHost.RestrictedUpdates.ADD_LIVE_DAO_0), payload);

            vm.prank(MULTISIG);
            IERC20(exchangeAsset).approve(address(host), amount * 3);

            vm.prank(MULTISIG);
            host.updateRestricted(uint(IHost.RestrictedUpdates.ADD_LIVE_DAO_0), payload);

            assertEq(IERC20(exchangeAsset).balanceOf(MULTISIG), amount * 2, "balance after 1st dao");
        }

        // -------------------- not unique symbol
        vm.expectRevert(abi.encodeWithSelector(IHost.SymbolNotUnique.selector, "testdao"));
        vm.prank(MULTISIG);
        host.updateRestricted(uint(IHost.RestrictedUpdates.ADD_LIVE_DAO_0), payload);

        // -------------------- only verifier (restricted)
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        host.updateRestricted(uint(IHost.RestrictedUpdates.ADD_LIVE_DAO_0), payload);

        // -------------------- todo validation
    }

    function testProcessUnitRevenue() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);

        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = HostUtilsLib.generateSeedFunding(
            HostUtilsLib.DEFAULT_SEED_DELAY,
            HostUtilsLib.DEFAULT_SEED_DURATION,
            HostUtilsLib.DEFAULT_SEED_MIN_RAISE,
            HostUtilsLib.DEFAULT_SEED_MAX_RAISE
        );

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = HostUtilsLib.generateDaoParams(365, 100);

        // ----------------------------- prepare to pay creation fee
        address exchangeAsset = host.getChainSettings().exchangeAsset;
        uint amount = host.getSettings().priceDao;

        deal(exchangeAsset, address(this), amount * 3);

        IERC20(exchangeAsset).approve(address(host), amount * 3);

        // ----------------------------- create first (host) dao
        host.createDAO(DAO_NAME, DAO_SYMBOL, activity, params, funding);
        assertEq(host.unitBalance(DAO_SYMBOL, HostLib.HOST_UNIT), amount, "host dao paid creation fee to itself");
        assertEq(
            IERC20(exchangeAsset).balanceOf(address(this)), amount * 2, "user has paid for creation of the first dao"
        );
        assertEq(IERC20(exchangeAsset).balanceOf(address(host)), amount, "creation fee is on balance of the host");

        // ----------------------------- create second-dao
        host.createDAO("name2", "symbol2", activity, params, funding);
        assertEq(
            host.unitBalance(DAO_SYMBOL, HostLib.HOST_UNIT), amount * 2, "second dao paid creation fee to host dao"
        );
        assertEq(host.unitBalance("symbol2", HostLib.HOST_UNIT), 0, "second dao has not received any fees yet");
        assertEq(IERC20(exchangeAsset).balanceOf(address(this)), amount, "user has paid for creation of the second dao");
        assertEq(
            IERC20(exchangeAsset).balanceOf(address(host)), amount * 2, "both creation fees are on balance of the host"
        );

        // ----------------------------- pay to second dao to registered unit
        {
            IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](1);
            IDAOMetadata.UnitMetaData[] memory metas = new IDAOMetadata.UnitMetaData[](1);
            metas[0] = IDAOMetadata.UnitMetaData({
                name: "Unit A",
                status: IDAOMetadata.UnitStatus.LIVE_2,
                unitType: uint16(1),
                revenueShare: 1000,
                emoji: "emoji1",
                ui: new IDAOMetadata.UnitUiLink[](0),
                api: new string[](0)
            });
            units[0] = IDAOData.UnitDataInput({unitId: "unitA", developerUid: ""});

            host.updateDAO(
                "symbol2",
                uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
                codec.encode(units, codec.PAYLOAD_API_VERSION()),
                codec.encode(metas, codec.PAYLOAD_API_VERSION())
            );

            deal(exchangeAsset, address(this), 1e18);
            IERC20(exchangeAsset).approve(address(host), 1e18);
            host.processUnitRevenue("symbol2", "unitA", 1e18);

            assertEq(host.unitBalance("symbol2", "unitA"), 1e18, "second dao received the payment");
        }

        // ----------------------------- pay to second dao to NOT-registered unit
        {
            deal(exchangeAsset, address(this), 1e18);
            IERC20(exchangeAsset).approve(address(host), 1e18);

            vm.expectRevert(IHost.UnitNotFound.selector);
            host.processUnitRevenue("symbol2", "unitB", 1e18);
        }
    }

    function testProcessUnitRevenueAllowToUseZeroPriceDao() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);

        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = HostUtilsLib.generateSeedFunding(
            HostUtilsLib.DEFAULT_SEED_DELAY,
            HostUtilsLib.DEFAULT_SEED_DURATION,
            HostUtilsLib.DEFAULT_SEED_MIN_RAISE,
            HostUtilsLib.DEFAULT_SEED_MAX_RAISE
        );

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = HostUtilsLib.generateDaoParams(365, 100);

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
        host.createDAO(DAO_NAME, DAO_SYMBOL, activity, params, funding);
        assertEq(host.unitBalance(DAO_SYMBOL, HostLib.HOST_UNIT), 0, "no creation fee was paid for first dao");

        // ----------------------------- create second-dao
        host.createDAO("name2", "symbol2", activity, params, funding);
        assertEq(host.unitBalance(DAO_SYMBOL, HostLib.HOST_UNIT), 0, "no creation fee was paid for second dao");

        // ----------------------------- Bad paths: Set priceDao to NOT zero
        {
            IHost.HostSettings memory st = host.getSettings();
            st.priceDao = 1;

            vm.prank(MULTISIG);
            host.setSettings(st);
        }

        vm.expectRevert(IHost.IncorrectConfiguration.selector); // exchange asset cannot be zero
        host.createDAO("name3", "symbol3", activity, params, funding);
    }

    function testTasks() public {
        // todo
    }

    //endregion ----------------------------------- Unit tests

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
            ITokenomics.DaoImages memory images = ITokenomics.DaoImages({
                seedToken: "new/images/seed.png", tgeToken: "", token: "", xToken: "", daoToken: ""
            });
            host.updateDAO(
                dao.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_IMAGES_0),
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
            ITokenomics.DaoImages memory images =
                ITokenomics.DaoImages({seedToken: "1", tgeToken: "2", token: "3", xToken: "4", daoToken: "5"});
            host.updateDAO(
                dao.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_IMAGES_0),
                codec.encode(images, codec.PAYLOAD_API_VERSION()),
                ""
            );
        }

        {
            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.images.seedToken, "1", "seedToken updated");
            assertEq(daoAfter.images.tgeToken, "2", "tgeToken updated");
            assertEq(daoAfter.images.token, "3", "token updated");
            assertEq(daoAfter.images.xToken, "4", "xToken updated");
            assertEq(daoAfter.images.daoToken, "5", "daoToken updated");
        }
    }

    // todo phase seed

    // todo bad paths
    //endregion ----------------------------------- Update dao images

    //region ----------------------------------- Update socials
    function testUpdateDaoSocialsWithoutVoting() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _setupAccessManager(host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        {
            string[] memory socials = new string[](4);
            socials[0] = "updated-1";
            socials[1] = "2";
            socials[2] = "3";
            socials[3] = "4";

            vm.recordLogs();
            host.updateDAO(dao.symbol, uint16(ITokenomics.DAOAction.UPDATE_SOCIALS_1), codec.encode(socials), "");

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host, DAO_SYMBOL);
            ITokenomics.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(p.validationRequired, "validation required for socials update");
            assertFalse(p.votingRequired, "voting not required for socials update");
            assertEq(uint(p.status), uint(ITokenomics.VotingStatus.VOTING_0), "no voting results");

            IDAOData.DaoData memory daoBefore = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoBefore.socials.length, dao.socials.length, "proposal is not applied without validation");

            vm.prank(MULTISIG);
            host.validateProposal(proposalId, true, payload);

            ITokenomics.Proposal memory pAfter = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(pAfter.validationStatus == ITokenomics.ValidationStatus.APPROVED_1, "proposal is approved");
            assertEq(
                uint(pAfter.status),
                uint(ITokenomics.VotingStatus.VOTING_0),
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
            host.updateDAO(dao.symbol, uint16(ITokenomics.DAOAction.UPDATE_SOCIALS_1), codec.encode(socials), "");

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());
            bytes32 proposalId = HostUtilsLib.getLastProposalId(host, DAO_SYMBOL);
            ITokenomics.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
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
        _setupAccessManager(host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        // ------------------------------ Create proposal to update socials
        string[] memory socials = new string[](1);
        socials[0] = "1";

        vm.recordLogs();
        host.updateDAO(dao.symbol, uint16(ITokenomics.DAOAction.UPDATE_SOCIALS_1), codec.encode(socials), "");

        bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());
        bytes32 proposalId = HostUtilsLib.getLastProposalId(host, DAO_SYMBOL);

        {
            ITokenomics.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(p.validationStatus == ITokenomics.ValidationStatus.NONE_0, "proposal is not validated yet");
            assertEq(
                uint(p.status), uint(ITokenomics.VotingStatus.VOTING_0), "no voting results yet (no voting is required)"
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
            ITokenomics.Proposal memory pAfter = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(pAfter.validationStatus == ITokenomics.ValidationStatus.REJECTED_2, "proposal is rejected");
            assertEq(
                uint(pAfter.status),
                uint(ITokenomics.VotingStatus.VOTING_0),
                "no voting results yet (no voting is required)"
            );
        }
    }

    function testUpdateDaoSocialsWithVoting() public {
        // ------------------------------ Create HOST
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _setupAccessManager(host);

        // ------------------------------ Create DAO
        _dealAndApprove(host);
        IDAOData.DaoData memory daoData = HostUtilsLib.createAliensDao(vm, host, "ALIENS");

        // ------------------------------ Move to seed phase to enable voting
        _moveDaoToSeedPhase(host, codec, daoData.symbol);
        daoData = IDataReader(host.getChainSettings().dataReader).getDAO(daoData.symbol);

        // ------------------------------ Update socials with proposal
        string[] memory socials = new string[](3);
        socials[0] = "https://a.aa/a1";
        socials[1] = "https://b.bb/b2";
        socials[2] = "https://c.cc/c3";

        vm.recordLogs();
        host.updateDAO(daoData.symbol, uint16(ITokenomics.DAOAction.UPDATE_SOCIALS_1), codec.encode(socials), "");

        bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());
        bytes32 proposalId = HostUtilsLib.getLastProposalId(host, daoData.symbol);

        // ------------------------------ Check proposal status before validation and voting
        {
            ITokenomics.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertTrue(p.validationRequired, "validation required for socials update");
            assertTrue(p.votingRequired, "voting required for socials update");
            assertEq(uint(p.validationStatus), uint(ITokenomics.ValidationStatus.NONE_0), "no validation yet");
            assertEq(uint(p.status), uint(ITokenomics.VotingStatus.VOTING_0), "no voting yet");
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

            ITokenomics.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertEq(uint(p.validationStatus), uint(ITokenomics.ValidationStatus.APPROVED_1), "validated");
            assertEq(uint(p.status), uint(ITokenomics.VotingStatus.APPROVED_1), "approved in voting");

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(daoData.symbol);
            assertEq(daoAfter.socials.length, 3, "socials length");
            assertEq(daoAfter.socials[0], "https://a.aa/a1", "socials[0] updated");
            assertEq(daoAfter.socials[1], "https://b.bb/b2", "socials[1] updated");
            assertEq(daoAfter.socials[2], "https://c.cc/c3", "socials[2] updated");

            vm.revertToState(snapshot);
        }

        // ------------------------------ Rejected by voting
        {
            uint snapshot = vm.snapshotState();

            vm.prank(MULTISIG);
            host.receiveVotingResults(proposalId, false, payload);

            ITokenomics.Proposal memory p = IDataReader(host.getChainSettings().dataReader).proposal(proposalId);
            assertEq(uint(p.validationStatus), uint(ITokenomics.ValidationStatus.APPROVED_1), "validated");
            assertEq(uint(p.status), uint(ITokenomics.VotingStatus.REJECTED_2), "rejected in voting");

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
            IDAOMetadata.UnitUiLink[] memory notEmptyUi = new IDAOMetadata.UnitUiLink[](2);
            notEmptyUi[0] = IDAOMetadata.UnitUiLink({title: "link1", href: "https://link1.com"});
            notEmptyUi[1] = IDAOMetadata.UnitUiLink({title: "link2", href: "https://link2.com"});

            string[] memory notEmptyApi = new string[](3);
            notEmptyApi[0] = "https://api1.com";
            notEmptyApi[1] = "https://api2.com";
            notEmptyApi[2] = "https://api3.com";

            IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](2);
            IDAOMetadata.UnitMetaData[] memory metas = new IDAOMetadata.UnitMetaData[](2);
            metas[0] = IDAOMetadata.UnitMetaData({
                name: "Unit A",
                status: IDAOMetadata.UnitStatus.LIVE_2,
                unitType: uint16(1),
                revenueShare: 1000,
                emoji: "emoji1",
                ui: notEmptyUi,
                api: notEmptyApi
            });
            units[0] = IDAOData.UnitDataInput({unitId: "unitA", developerUid: ""});
            metas[1] = IDAOMetadata.UnitMetaData({
                name: "Unit B1",
                status: IDAOMetadata.UnitStatus.BUILDING_1,
                unitType: uint16(2),
                revenueShare: 2000,
                emoji: "emoji2",
                ui: new IDAOMetadata.UnitUiLink[](0),
                api: new string[](0)
            });
            units[1] = IDAOData.UnitDataInput({unitId: "unitB1", developerUid: "developerUid"});
            host.updateDAO(
                dao.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
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
            IDAOMetadata.UnitUiLink[] memory notEmptyUi = new IDAOMetadata.UnitUiLink[](1);
            notEmptyUi[0] = IDAOMetadata.UnitUiLink({title: "link2", href: "https://link2.com"});

            string[] memory notEmptyApi = new string[](1);
            notEmptyApi[0] = "https://api1.com";

            IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](1);
            IDAOMetadata.UnitMetaData[] memory metas = new IDAOMetadata.UnitMetaData[](1);
            metas[0] = IDAOMetadata.UnitMetaData({
                name: "Unit AAAA",
                status: IDAOMetadata.UnitStatus.BUILDING_1,
                unitType: uint16(2),
                revenueShare: 2000,
                emoji: "emoji222",
                ui: notEmptyUi,
                api: notEmptyApi
            });
            units[0] = IDAOData.UnitDataInput({unitId: "unitAAAA", developerUid: ""});
            host.updateDAO(
                dao.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
                codec.encode(units, codec.PAYLOAD_API_VERSION()),
                codec.encode(metas, codec.PAYLOAD_API_VERSION())
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.units.length, 1, "units length");

            // todo
            //            assertEq(daoAfter.units[0].ui.length, 1, "ui length");
            //            assertEq(daoAfter.units[0].api.length, 1, "api length");
            assertTrue(
                keccak256(abi.encode(units[0].unitId)) == keccak256(abi.encode(daoAfter.units[0].unitId)), "unitId-eq3"
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

        ITokenomics.Funding memory seed;
        seed.fundingType = ITokenomics.FundingType.SEED_0;
        seed.start = 100;
        seed.end = 200;
        seed.minRaise = 1000;
        seed.maxRaise = 5000;
        seed.raised = 250;
        seed.claim = 1;

        {
            host.updateDAO(
                dao.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4),
                codec.encode(seed, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.funding.length, 1, "funding length");

            ITokenomics.Funding memory fundingAfter = daoAfter.funding[0];

            assertEq(uint8(fundingAfter.fundingType), uint8(seed.fundingType));
            assertEq(uint64(fundingAfter.start), uint64(seed.start));
            assertEq(uint64(fundingAfter.end), uint64(seed.end));
            assertEq(fundingAfter.minRaise, seed.minRaise);
            assertEq(fundingAfter.maxRaise, seed.maxRaise);
            assertEq(fundingAfter.raised, seed.raised);
            assertEq(fundingAfter.claim, seed.claim);
        }

        {
            ITokenomics.Funding memory tge;
            tge.fundingType = ITokenomics.FundingType.TGE_1;
            tge.start = 1001;
            tge.end = 2002;
            tge.minRaise = 10003;
            tge.maxRaise = 50004;
            tge.raised = 2505;
            tge.claim = 16;

            host.updateDAO(
                dao.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_FUNDING_4),
                codec.encode(tge, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.funding.length, 2, "funding length");

            ITokenomics.Funding memory seed0 = daoAfter.funding[0];
            ITokenomics.Funding memory tge1 = daoAfter.funding[1];

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

        {
            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](2);
            vesting[0] =
                ITokenomics.Vesting({name: "Team", description: "team vesting", allocation: 1000, start: 1, end: 100});
            vesting[1] =
                ITokenomics.Vesting({name: "Seed", description: "seed vesting", allocation: 2000, start: 2, end: 200});

            host.updateDAO(
                dao.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_VESTING_5),
                codec.encode(vesting, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.vesting.length, 2, "vesting length");

            assertEq(keccak256(abi.encode(daoAfter.vesting[0])), keccak256(abi.encode(vesting[0])), "vesting[0] eq");
            assertEq(keccak256(abi.encode(daoAfter.vesting[1])), keccak256(abi.encode(vesting[1])), "vesting[1] eq");
        }

        {
            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0] = ITokenomics.Vesting({
                name: "Team3", description: "team vesting3", allocation: 10003, start: 3, end: 300
            });

            host.updateDAO(
                dao.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_VESTING_5),
                codec.encode(vesting, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);
            assertEq(daoAfter.vesting.length, 1, "vesting length 2");

            assertEq(keccak256(abi.encode(daoAfter.vesting[0])), keccak256(abi.encode(vesting[0])), "vesting[0] eq");
        }
    }

    //endregion ----------------------------------- Update vesting

    //region ----------------------------------- Update naming
    // todo fix: validation
    function testUpdateNamingInstant() internal {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        {
            ITokenomics.DaoNames memory naming = ITokenomics.DaoNames({name: "New DAO Name", symbol: "NEWDS"});

            bytes memory payload = codec.encode(naming, codec.PAYLOAD_API_VERSION());

            host.updateDAO(dao.symbol, uint16(ITokenomics.DAOAction.UPDATE_NAMING_2), payload, "");

            bytes32 proposalId = HostUtilsLib.getLastProposalId(host, dao.symbol);

            vm.prank(MULTISIG);
            host.validateProposal(proposalId, true, payload);

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(naming.symbol);

            assertEq(daoAfter.name, naming.name, "name updated");
            assertEq(daoAfter.deployer, dao.deployer, "deployer wasn't changed");
        }
    }

    // todo test case: X exists, X decides to change name to Y, Y is created while X voting is in progress, X cannot change name to Y

    //endregion ----------------------------------- Update naming

    //region ----------------------------------- Update dao parameters
    function testUpdateDaoParametersInstant() public {
        IHost host = HostUtilsLib.createHostInstance(vm, MULTISIG);
        IHostCodec codec = HostUtilsLib.createHostCodec(vm, MULTISIG, host);
        _dealAndApprove(host);
        IDAOData.DaoData memory dao = HostUtilsLib.createDaoInstance(host, DAO_SYMBOL, DAO_NAME);

        {
            ITokenomics.DaoParameters memory a;
            a.vePeriod = 100;
            a.pvpFee = 10;
            a.minPower = 1000;
            a.ttBribe = 1;
            a.recoveryShare = 2;
            a.proposalThreshold = 50;

            host.updateDAO(
                dao.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6),
                codec.encode(a, codec.PAYLOAD_API_VERSION()),
                ""
            );

            IDAOData.DaoData memory daoAfter = IDataReader(host.getChainSettings().dataReader).getDAO(dao.symbol);

            assertEq(keccak256(abi.encode(daoAfter.params)), keccak256(abi.encode(a)), "params");
        }
    }

    //endregion ----------------------------------- Update dao parameters

    //region ----------------------------------- Internal logic
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
            ITokenomics.Funding memory ef = expected.funding[i];
            ITokenomics.Funding memory af = actual.funding[i];

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
            ITokenomics.Vesting memory ev = expected.vesting[i];
            ITokenomics.Vesting memory av = actual.vesting[i];

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

    function _setupAccessManager(IHost host) internal {
        address authority = IAccessManaged(address(host)).authority();

        // --------------------------------- For simplicity use same role 5555 for ALL restricted functions in this set of tests
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = bytes4(IHost.setSettings.selector);
        selectors[1] = bytes4(IHost.setChainSettings.selector);
        selectors[2] = bytes4(IHost.updateRestricted.selector);
        selectors[3] = bytes4(IHost.refundFor.selector);
        selectors[4] = bytes4(IHost.onReceiveCrossChainMessage.selector);
        selectors[5] = bytes4(IHost.receiveVotingResults.selector);
        selectors[6] = bytes4(IHost.validateProposal.selector);
        selectors[7] = bytes4(IHost.setContractImplementation.selector);
        selectors[8] = bytes4(IHost.deployProxy.selector);

        vm.prank(MULTISIG);
        IAccessManager(address(authority)).setTargetFunctionRole(address(host), selectors, 5555);

        vm.prank(MULTISIG);
        IAccessManager(address(authority)).grantRole(5555, MULTISIG, 0);
    }

    function _moveDaoToSeedPhase(IHost host_, IHostCodec codec_, string memory symbol) internal {
        IDAOData.DaoData memory daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(symbol);
        skip(7 days);

        IDAOMetadata.UnitMetaData memory unitMetadata0 = IDAOMetadata.UnitMetaData({
            name: "DAO Factory",
            status: IDAOMetadata.UnitStatus.BUILDING_1,
            unitType: uint16(IDAOMetadata.UnitType.DEFI_PROTOCOL_1),
            revenueShare: 100,
            ui: new IDAOMetadata.UnitUiLink[](0),
            emoji: "",
            api: new string[](0)
        });

        {
            IHost.Task[] memory tasks = host_.tasks(daoData.symbol);
            assertGe(tasks.length, 2, "at least 2 unsolved tasks");
            //HostUtilsLib.printTasks(tasks);

            // deployer drew token logotypes
            ITokenomics.DaoImages memory images = ITokenomics.DaoImages({
                seedToken: "/seedAliens.png", tgeToken: "", token: "/aliens.png", xToken: "", daoToken: ""
            });
            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_IMAGES_0),
                codec_.encode(images, codec_.PAYLOAD_API_VERSION()),
                ""
            );

            // units project
            IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](1);
            IDAOMetadata.UnitMetaData[] memory metas = new IDAOMetadata.UnitMetaData[](1);
            metas[0] = unitMetadata0;
            units[0] = IDAOData.UnitDataInput({unitId: "aliens:os", developerUid: ""});

            host_.updateDAO(
                daoData.symbol,
                uint16(ITokenomics.DAOAction.UPDATE_UNITS_3),
                codec_.encode(units, codec_.PAYLOAD_API_VERSION()),
                codec_.encode(metas, codec_.PAYLOAD_API_VERSION())
            );

            // registered socials
            string[] memory socials = new string[](2);
            socials[0] = "https://a.aa/a";
            socials[1] = "https://b.bb/b";

            vm.recordLogs();
            host_.updateDAO(daoData.symbol, uint16(ITokenomics.DAOAction.UPDATE_SOCIALS_1), codec_.encode(socials), "");

            bytes memory payload = HostUtilsLib.extractProposalPayload(vm.getRecordedLogs());
            bytes32 proposalId = HostUtilsLib.getLastProposalId(host_, daoData.symbol);

            vm.prank(MULTISIG);
            host_.validateProposal(proposalId, true, payload);
        }

        // ------------------------------ fix funding
        {
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

        skip(24 days);

        // ------------------------------ change phase to seed
        host_.changePhase(daoData.symbol);

        // ------------------------------ setup seed token, refresh daoData
        {
            daoData = IDataReader(host_.getChainSettings().dataReader).getDAO(daoData.symbol);
            HostUtilsLib.setupSeedToken(vm, host_, MULTISIG, daoData.deployments.seedToken);
        }
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
