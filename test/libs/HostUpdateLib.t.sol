// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";
import {Test} from "forge-std/Test.sol";
import {MockHost} from "../mocks/MockHost.sol";
import {Authority} from "../../src/Authority.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {HostConfigLib} from "../../src/libs/HostConfigLib.sol";
import {HostLib} from "../../src/libs/HostLib.sol";
import {HostUpdateLib} from "../../src/libs/HostUpdateLib.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IDAOData} from "../../src/interfaces/IDAOData.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {HostEncodingLib} from "../../src/libs/HostEncodingLib.sol";
import {MockHostBridge} from "../mocks/MockHostBridge.sol";
import {SampleDataLib} from "../utils/SampleDataLib.sol";

contract HostUpdateLibTest is Test {
    MockERC20 internal exchangeAsset;

    /// @dev msg.sender (it cannot be changed by vm.prank in library calls)
    address internal user;
    address public multisig;
    IAuthority public authority;

    /// @dev Default claim = block.timestamp + offset
    uint public constant DEFAULT_CLAIM_OFFSET = 2 days;

    struct TestCaseFunding {
        ITokenomics.LifecyclePhase phase;
        ITokenomics.FundingType fundingType;
    }

    constructor() {
        multisig = makeAddr("multisig");
        authority = _createAuthority();

        /// @dev We call library directly, internal msg.sender is not overwritten by vm.prank
        user = msg.sender;
        exchangeAsset = new MockERC20("Exchange Asset", "EXA", 18);

        HostConfigLib.getHostChainSettings().exchangeAsset = address(exchangeAsset);
    }

    //region ------------------------------------------ Tests for validation
    function testValidateNaming() public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        st.maxNameLength = 5;
        st.minNameLength = 3;
        st.maxSymbolLength = 3;
        st.minSymbolLength = 2;
        this.validateNamingPublic("abcd", "AB");
        this.validateNamingPublic("12345", "123");

        vm.expectRevert(abi.encodeWithSelector(IHost.NameLength.selector, uint(6)));
        this.validateNamingPublic("123456", "123");

        vm.expectRevert(abi.encodeWithSelector(IHost.SymbolLength.selector, uint(4)));
        this.validateNamingPublic("12345", "1234");

        vm.expectRevert(abi.encodeWithSelector(IHost.NameLength.selector, uint(2)));
        this.validateNamingPublic("12", "123");

        vm.expectRevert(abi.encodeWithSelector(IHost.SymbolLength.selector, uint(1)));
        this.validateNamingPublic("123", "1");

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 1;

        vm.expectRevert(abi.encodeWithSelector(IHost.SymbolNotUnique.selector, "ABC"));
        this.validateNamingPublic("abcd", "ABC");
    }

    function testValidateNamingUppercase() public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        st.maxNameLength = 50;
        st.maxSymbolLength = 30;

        this.validateNamingPublic("", "ABC");
        this.validateNamingPublic("", "ABC123");
        this.validateNamingPublic("", "123");

        vm.expectRevert(abi.encodeWithSelector(IHost.UpperCaseRequired.selector, "aBC"));
        this.validateNamingPublic("", "aBC");

        vm.expectRevert(abi.encodeWithSelector(IHost.UpperCaseRequired.selector, "AbC"));
        this.validateNamingPublic("", "AbC");

        vm.expectRevert(abi.encodeWithSelector(IHost.UpperCaseRequired.selector, "ABc"));
        this.validateNamingPublic("", "ABc");

        vm.expectRevert(abi.encodeWithSelector(IHost.UpperCaseRequired.selector, "abc"));
        this.validateNamingPublic("", "abc");

        vm.expectRevert(abi.encodeWithSelector(IHost.UpperCaseRequired.selector, "a1"));
        this.validateNamingPublic("", "a1");
    }

    function testValidateDaoData() public {
        // just ensure that {_validateNaming} is called inside {_validateDaoData}
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        st.maxNameLength = 5;
        st.minNameLength = 3;
        st.maxSymbolLength = 3;
        st.minSymbolLength = 2;

        HostLib.DaoDataSegment2 memory dao;
        dao.name = "123456";
        dao.symbol = "abc";

        vm.expectRevert(abi.encodeWithSelector(IHost.NameLength.selector, uint(6)));
        this.validateDaoDataPublic(dao);
    }

    function testValidateDaoParameters_ChangeTotalSupplyAfterTgeStarted_Throws() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ITokenomics.DaoParameters memory data;
        data.proposalThreshold = 1;

        // ------------------ Set initial version of total supply
        data.totalSupply = 100_000_000e18;
        this.validateDaoParametersPublic(117, ITokenomics.LifecyclePhase.DRAFT_0, data);
        $.daoParameters[117] = data;

        // ------------------ Change total supply in SEED
        data.totalSupply = 110_000_000e18;
        this.validateDaoParametersPublic(117, ITokenomics.LifecyclePhase.SEED_2, data);
        $.daoParameters[117] = data;

        // ------------------ Change total supply in DEVELOPMENT
        data.totalSupply = 120_000_000e18;
        this.validateDaoParametersPublic(117, ITokenomics.LifecyclePhase.DEVELOPMENT_4, data);
        $.daoParameters[117] = data;

        // ------------------ Fail to change total supply after TGE started
        data.totalSupply = 130_000_000e18;
        vm.expectRevert(IHost.TooLateToUpdateTotalSupply.selector);
        this.validateDaoParametersPublic(117, ITokenomics.LifecyclePhase.TGE_5, data);

        // ------------------ Other parameters can be updated after TGE started
        data.totalSupply = 120_000_000e18;
        data.proposalThreshold = 2;
        this.validateDaoParametersPublic(117, ITokenomics.LifecyclePhase.TGE_5, data);
        $.daoParameters[117] = data;
    }

    function testValidateActivity_Success() public view {
        uint count = uint(ITokenomics.Activity.COUNT_ACTIVITY);
        { // all activity
            ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](count);
            for (uint i = 0; i < count; i++) {
                activity[i] = ITokenomics.Activity(i);
            }
            this.validateActivityPublic(activity);
        }

        { // empty activity
            ITokenomics.Activity[] memory activity;
            this.validateActivityPublic(activity);
        }

        // single activity (not builder)
        for (uint i = 0; i < uint(ITokenomics.Activity.COUNT_ACTIVITY); i++) {
            if (i != uint(ITokenomics.Activity.BUILDER_3)) {
                ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
                activity[0] = ITokenomics.Activity(i);
                this.validateActivityPublic(activity);
            }
        }
        { // builder + one more activity
            ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](2);
            activity[0] = ITokenomics.Activity.BUILDER_3;
            activity[1] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;
            this.validateActivityPublic(activity);
        }
    }

    function testValidateActivityNegative() public {
        { // builder alone
            ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
            activity[0] = ITokenomics.Activity.BUILDER_3;
            vm.expectRevert(abi.encodeWithSelector(IHost.SingleBuilderActivityNotAllowed.selector));
            this.validateActivityPublic(activity);
        }

        // activity repeat
        for (uint i = 0; i < uint(ITokenomics.Activity.COUNT_ACTIVITY); i++) {
            if (i != uint(ITokenomics.Activity.BUILDER_3)) {
                ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](2);
                activity[0] = ITokenomics.Activity(i);
                activity[1] = ITokenomics.Activity(i);
                vm.expectRevert(abi.encodeWithSelector(IHost.InvalidActivityCombination.selector));
                this.validateActivityPublic(activity);
            }
        }

        // no need to test incorrect enum values - solidity decoder doesn't allow that
    }

    function testValidateDaoParameters_Success() public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        st.minPvPFee = 100;
        st.maxPvPFee = 1000;
        st.minVePeriod = 14;
        st.maxVePeriod = 365;

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 500;
            params.vePeriod = 30;
            this.validateDaoParametersPublic(1, ITokenomics.LifecyclePhase.DRAFT_0, params);
        }

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 100;
            params.vePeriod = 14;
            this.validateDaoParametersPublic(1, ITokenomics.LifecyclePhase.DRAFT_0, params);
        }

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 1000;
            params.vePeriod = 365;
            this.validateDaoParametersPublic(1, ITokenomics.LifecyclePhase.DRAFT_0, params);
        }
    }

    function testValidateDaoParametersNegative() public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        st.minPvPFee = 100;
        st.maxPvPFee = 1000;
        st.minVePeriod = 14;
        st.maxVePeriod = 365;

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 99;
            params.vePeriod = 30;
            vm.expectRevert(abi.encodeWithSelector(IHost.PvPFee.selector, uint(99)));
            this.validateDaoParametersPublic(1, ITokenomics.LifecyclePhase.DRAFT_0, params);
        }

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 1001;
            params.vePeriod = 30;
            vm.expectRevert(abi.encodeWithSelector(IHost.PvPFee.selector, uint(1001)));
            this.validateDaoParametersPublic(1, ITokenomics.LifecyclePhase.DRAFT_0, params);
        }

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 500;
            params.vePeriod = 13;
            vm.expectRevert(abi.encodeWithSelector(IHost.VePeriod.selector, uint(13)));
            this.validateDaoParametersPublic(1, ITokenomics.LifecyclePhase.DRAFT_0, params);
        }

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 500;
            params.vePeriod = 366;
            vm.expectRevert(abi.encodeWithSelector(IHost.VePeriod.selector, uint(366)));
            this.validateDaoParametersPublic(1, ITokenomics.LifecyclePhase.DRAFT_0, params);
        }
    }

    function testValidateChainSettings_Success() public {
        {
            ITokenomics.DaoChainSettings memory st;
            st.bbRate = 0;
            st.multisig = address(0);
            this.validateChainSettingsPublic(st);
        }

        {
            ITokenomics.DaoChainSettings memory st;
            st.bbRate = 100;
            st.multisig = makeAddr("multisig");
            this.validateChainSettingsPublic(st);
        }

        {
            ITokenomics.DaoChainSettings memory st;
            st.bbRate = 35;
            st.multisig = address(0);
            this.validateChainSettingsPublic(st);
        }
    }

    function testValidateChainSettings_BbRateOutOfRange_Revert() public {
        ITokenomics.DaoChainSettings memory st;
        st.bbRate = 101;
        st.multisig = address(0);

        vm.expectRevert(IHost.TooHighValue.selector);
        this.validateChainSettingsPublic(st);
    }

    //endregion ------------------------------------------ Tests for validation

    //region ------------------------------------------ Tests for Activity validation
    function testValidateActivityEmpty() public view {
        ITokenomics.Activity[] memory activity;
        this.validateActivityPublic(activity);
    }

    function testValidateActivityNormal() public view {
        uint count = uint(ITokenomics.Activity.COUNT_ACTIVITY);
        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](count);
        for (uint i = 0; i < count; i++) {
            activity[i] = ITokenomics.Activity(i);
        }
        this.validateActivityPublic(activity);
    }

    function testValidateActivity_DuplicateActivity_Throws() public {
        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](2);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;
        activity[1] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        vm.expectRevert(abi.encodeWithSelector(IHost.InvalidActivityCombination.selector));
        this.validateActivityPublic(activity);
    }

    function testValidateActivity_BuilderAlone_Throws() public {
        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.BUILDER_3;

        vm.expectRevert(abi.encodeWithSelector(IHost.SingleBuilderActivityNotAllowed.selector));
        this.validateActivityPublic(activity);
    }

    //endregion ------------------------------------------ Tests for Activity validation

    //region ------------------------------------------ Tests for Funding validation
    function fixtureFundingType() public pure returns (ITokenomics.FundingType[] memory) {
        ITokenomics.FundingType[] memory fundingTypes = new ITokenomics.FundingType[](2);
        fundingTypes[0] = ITokenomics.FundingType.TGE_1;
        fundingTypes[1] = ITokenomics.FundingType.SEED_0;

        return fundingTypes;
    }

    function tableValidateFundingListPositive(ITokenomics.FundingType fundingType) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;
        {
            console.log("block.timestamp", block.timestamp);
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
            funding[0].start = uint64(block.timestamp + 1 days);
            funding[0].end = uint64(block.timestamp + 10 days);
            funding[0].minRaise = 1e18;
            funding[0].maxRaise = 100e18;
            funding[0].fundingType = fundingType;

            this.validateFundingListPublic(funding);
        }

        {
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](2);
            funding[0].start = uint64(block.timestamp + 1 days);
            funding[0].end = uint64(block.timestamp + 10 days);
            funding[0].minRaise = 1e18;
            funding[0].maxRaise = 100e18;
            funding[0].fundingType = fundingType;

            funding[1].start = uint64(block.timestamp + 1 days);
            funding[1].end = uint64(block.timestamp + 10 days);
            funding[1].minRaise = 1e18;
            funding[1].maxRaise = 100e18;
            funding[1].fundingType = fundingType == ITokenomics.FundingType.SEED_0
                ? ITokenomics.FundingType.TGE_1
                : ITokenomics.FundingType.SEED_0;

            this.validateFundingListPublic(funding);
        }
    }

    function tableValidateFundingListNegative_NotUniqueFundingTypes_Throws(ITokenomics.FundingType fundingType) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;

        // ----------------- funding array has not unique funding types
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](2);
        funding[0].start = uint64(block.timestamp + 1 days);
        funding[0].end = uint64(block.timestamp + 10 days);
        funding[0].minRaise = 1e18;
        funding[0].maxRaise = 100e18;
        funding[0].fundingType = fundingType;

        funding[1].start = uint64(block.timestamp + 1 days);
        funding[1].end = uint64(block.timestamp + 10 days);
        funding[1].minRaise = 1e18;
        funding[1].maxRaise = 100e18;
        funding[1].fundingType = fundingType;

        vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingArray.selector));
        this.validateFundingListPublic(funding);
    }

    function tableValidateFundingListNegative_EndLessStart_Throws(ITokenomics.FundingType fundingType) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;

        // ------------------ end < start
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0].start = uint64(block.timestamp + 1 days);
        funding[0].end = 0; // (!)
        funding[0].minRaise = 1e18;
        funding[0].maxRaise = 100e18;
        funding[0].fundingType = fundingType;

        vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingPeriod.selector));
        this.validateFundingListPublic(funding);
    }

    function tableValidateFundingListNegative_DurationLessMin_Throws(ITokenomics.FundingType fundingType) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;

        // ------------------ duration < minFundingDuration
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0].start = uint64(block.timestamp + 1 days);
        funding[0].end = uint64(block.timestamp + 7 days);
        funding[0].minRaise = 1e18;
        funding[0].maxRaise = 100e18;
        funding[0].fundingType = fundingType;

        vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingPeriod.selector));
        this.validateFundingListPublic(funding);
    }

    function tableValidateFundingListNegative_DurationGreaterMax_Throws(ITokenomics.FundingType fundingType) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;

        // ------------------ duration > maxFundingDuration
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0].start = uint64(block.timestamp + 1 days);
        funding[0].end = uint64(block.timestamp + 91 days + 1);
        funding[0].minRaise = 1e18;
        funding[0].maxRaise = 100e18;
        funding[0].fundingType = fundingType;

        vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingPeriod.selector));
        this.validateFundingListPublic(funding);
    }

    function tableValidateFundingListNegative_MaxRaiseLessMinRaise_Throws(ITokenomics.FundingType fundingType) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;

        // ------------------ maxRaise < minRaise
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0].start = uint64(block.timestamp + 1 days);
        funding[0].end = uint64(block.timestamp + 45 days);
        funding[0].minRaise = 100e18;
        funding[0].maxRaise = 1e18;
        funding[0].fundingType = fundingType;

        vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingRaise.selector));
        this.validateFundingListPublic(funding);
    }

    function tableValidateFundingListNegative_MinRaiseLessMinFundingRaise(ITokenomics.FundingType fundingType) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;

        // ------------------ minRaise < minFunding
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0].start = uint64(block.timestamp + 1 days);
        funding[0].end = uint64(block.timestamp + 45 days);
        funding[0].minRaise = st.minFundingRaise - 1;
        funding[0].maxRaise = 1000e18;
        funding[0].fundingType = fundingType;

        vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingRaise.selector));
        this.validateFundingListPublic(funding);
    }

    function testValidateSeedFundingPositive() public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;
        {
            ITokenomics.Funding memory funding;
            funding.start = uint64(block.timestamp + 1 days);
            funding.end = uint64(block.timestamp + 10 days);
            funding.minRaise = 1e18;
            funding.maxRaise = 100e18;
            funding.fundingType = ITokenomics.FundingType.SEED_0;

            this.validateFundingPublic(ITokenomics.LifecyclePhase.DRAFT_0, funding);
        }
    }

    function testValidateTgeFundingPositive() public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;
        {
            ITokenomics.Funding memory funding;
            funding.start = uint64(block.timestamp + 1 days);
            funding.end = uint64(block.timestamp + 10 days);
            funding.minRaise = 1e18;
            funding.maxRaise = 100e18;
            funding.fundingType = ITokenomics.FundingType.TGE_1;

            this.validateFundingPublic(ITokenomics.LifecyclePhase.DEVELOPMENT_4, funding);
        }
    }

    function fixtureGoodFundingPhase() public pure returns (TestCaseFunding[] memory tests) {
        tests = new TestCaseFunding[](uint(ITokenomics.LifecyclePhase.SEED_2) + 4);
        uint n;
        for (uint i = 0; i < uint(ITokenomics.LifecyclePhase.SEED_2); i++) {
            tests[n++] =
                TestCaseFunding({phase: ITokenomics.LifecyclePhase(i), fundingType: ITokenomics.FundingType.SEED_0});
        }
        tests[n++] =
            TestCaseFunding({phase: ITokenomics.LifecyclePhase.DRAFT_0, fundingType: ITokenomics.FundingType.TGE_1});
        tests[n++] = TestCaseFunding({
            phase: ITokenomics.LifecyclePhase.INCEPTION_1, fundingType: ITokenomics.FundingType.TGE_1
        });
        tests[n++] =
            TestCaseFunding({phase: ITokenomics.LifecyclePhase.SEED_2, fundingType: ITokenomics.FundingType.TGE_1});
        tests[n++] = TestCaseFunding({
            phase: ITokenomics.LifecyclePhase.DEVELOPMENT_4, fundingType: ITokenomics.FundingType.TGE_1
        });
    }

    function tableValidateFundingNegativeGoodPhase(TestCaseFunding memory goodFundingPhase) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;

        { // ------------------ end < start
            ITokenomics.Funding memory funding;
            funding.start = uint64(block.timestamp + 1 days);
            funding.end = 0; // (!)
            funding.minRaise = 1e18;
            funding.maxRaise = 100e18;
            funding.fundingType = goodFundingPhase.fundingType;

            vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingPeriod.selector));
            this.validateFundingPublic(goodFundingPhase.phase, funding);
        }

        { // ------------------ duration < minFundingDuration
            ITokenomics.Funding memory funding;
            funding.start = uint64(block.timestamp + 1 days);
            funding.end = uint64(block.timestamp + 7 days);
            funding.minRaise = 1e18;
            funding.maxRaise = 100e18;
            funding.fundingType = goodFundingPhase.fundingType;

            vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingPeriod.selector));
            this.validateFundingPublic(goodFundingPhase.phase, funding);
        }

        { // ------------------ duration > maxFundingDuration
            ITokenomics.Funding memory funding;
            funding.start = uint64(block.timestamp + 1 days);
            funding.end = uint64(block.timestamp + 91 days + 1);
            funding.minRaise = 1e18;
            funding.maxRaise = 100e18;
            funding.fundingType = goodFundingPhase.fundingType;

            vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingPeriod.selector));
            this.validateFundingPublic(goodFundingPhase.phase, funding);
        }

        {} // ------------------ start of SEED < dao creation time + maxSeedStartDelay
        // todo add dao creation date

        { // ------------------ minRaise < maxRaise
            ITokenomics.Funding memory funding;
            funding.start = uint64(block.timestamp + 1 days);
            funding.end = uint64(block.timestamp + 45 days);
            funding.minRaise = 100e18;
            funding.maxRaise = 1e18;
            funding.fundingType = goodFundingPhase.fundingType;

            vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingRaise.selector));
            this.validateFundingPublic(goodFundingPhase.phase, funding);
        }

        { // ------------------ minRaise < minFunding
            ITokenomics.Funding memory funding;
            funding.start = uint64(block.timestamp + 1 days);
            funding.end = uint64(block.timestamp + 45 days);
            funding.minRaise = st.minFundingRaise - 1;
            funding.maxRaise = 1000e18;
            funding.fundingType = goodFundingPhase.fundingType;

            vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingRaise.selector));
            this.validateFundingPublic(goodFundingPhase.phase, funding);
        }
    }

    function fixtureBadFundingPhase() public pure returns (TestCaseFunding[] memory tests) {
        uint countPhases = uint(ITokenomics.LifecyclePhase.COUNT_LIFECYCLE_PHASES);

        tests = new TestCaseFunding[](
            2 * countPhases - uint(ITokenomics.LifecyclePhase.SEED_2) - uint(ITokenomics.LifecyclePhase.TGE_5) + 1
        );
        uint n;
        for (uint i = uint(ITokenomics.LifecyclePhase.SEED_2); i < countPhases; i++) {
            tests[n++] =
                TestCaseFunding({phase: ITokenomics.LifecyclePhase(i), fundingType: ITokenomics.FundingType.SEED_0});
        }
        tests[n++] = TestCaseFunding({
            phase: ITokenomics.LifecyclePhase.SEED_FAILED_3, fundingType: ITokenomics.FundingType.TGE_1
        });
        for (uint i = uint(ITokenomics.LifecyclePhase.TGE_5); i < countPhases; i++) {
            tests[n++] =
                TestCaseFunding({phase: ITokenomics.LifecyclePhase(i), fundingType: ITokenomics.FundingType.TGE_1});
        }
    }

    function tableValidateFundingNegativeBadPhase(TestCaseFunding memory badFundingPhase) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;
        st.minFundingRaise = 0.1e18;
        st.maxFundingRaise = 1000e18;

        ITokenomics.Funding memory funding;
        funding.start = uint64(block.timestamp + 1 days);
        funding.end = uint64(block.timestamp + 10 days);
        funding.minRaise = 1e18;
        funding.maxRaise = 100e18;
        funding.fundingType = badFundingPhase.fundingType;

        vm.expectRevert(abi.encodeWithSelector(IHost.TooLateToUpdateSuchFunding.selector));
        this.validateFundingPublic(badFundingPhase.phase, funding);
    }

    //endregion ------------------------------------------ Tests for Funding validation

    //region ------------------------------------------ Tests for Vesting validation
    /// @dev Source data for tableVestingListGoodPhase_XXX
    function fixtureVestingGoodPhase() public pure returns (ITokenomics.LifecyclePhase[] memory phases) {
        uint countPhases = uint(ITokenomics.LifecyclePhase.COUNT_LIFECYCLE_PHASES);
        uint n;
        phases = new ITokenomics.LifecyclePhase[](countPhases - 3);
        for (uint i; i < countPhases - 3; i++) {
            ITokenomics.LifecyclePhase phase = ITokenomics.LifecyclePhase(i);
            if (
                phase != ITokenomics.LifecyclePhase.LIVE_CLIFF_6 && phase != ITokenomics.LifecyclePhase.LIVE_VESTING_7
                    && phase != ITokenomics.LifecyclePhase.LIVE_8
            ) {
                phases[n++] = ITokenomics.LifecyclePhase(i);
            }
        }
    }

    function tableVestingListGoodPhase_LenNameInRange_Ok(ITokenomics.LifecyclePhase vestingGoodPhase) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minVestingNameLen = 5;
        st.maxVestingNameLen = 7;
        st.minVePeriod = 14;
        st.maxVePeriod = 365;
        st.minCliff = 7;

        ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](2);
        vesting[0].name = "12345";
        vesting[0].description = "vesting description";
        vesting[0].allocation = 45_000;
        vesting[0].start = uint64(block.timestamp + 10 days);
        vesting[0].end = uint64(block.timestamp + 50 days);

        vesting[1].name = "1234567";
        vesting[1].description = "vesting 2";
        vesting[1].allocation = 45_000;
        vesting[1].start = uint64(block.timestamp + 15 days);
        vesting[1].end = uint64(block.timestamp + 50 days);

        this.validateVestingListPublic(vestingGoodPhase, vesting, block.timestamp + DEFAULT_CLAIM_OFFSET);
    }

    function tableVestingListGoodPhase_LenNameOutOfRange_Throws(ITokenomics.LifecyclePhase vestingGoodPhase) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minVestingNameLen = 5;
        st.maxVestingNameLen = 7;
        st.minVePeriod = 14;
        st.maxVePeriod = 365;
        st.minCliff = 7;

        {
            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0].name = "1234";
            vesting[0].description = "vesting description";
            vesting[0].allocation = 50_000;
            vesting[0].start = uint64(block.timestamp + 10 days);
            vesting[0].end = uint64(block.timestamp + 50 days);

            vm.expectRevert(abi.encodeWithSelector(IHost.NameLength.selector, uint(4)));
            this.validateVestingListPublic(vestingGoodPhase, vesting, block.timestamp + DEFAULT_CLAIM_OFFSET);
        }
        {
            ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
            vesting[0].name = "12345678";
            vesting[0].description = "vesting description";
            vesting[0].allocation = 45_000;
            vesting[0].start = uint64(block.timestamp + 1 days);
            vesting[0].end = uint64(block.timestamp + 50 days);

            vm.expectRevert(abi.encodeWithSelector(IHost.NameLength.selector, uint(8)));
            this.validateVestingListPublic(vestingGoodPhase, vesting, block.timestamp + DEFAULT_CLAIM_OFFSET);
        }
    }

    function tableVestingListGoodPhase_ZeroAllocation_Throws(ITokenomics.LifecyclePhase vestingGoodPhase) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minVestingNameLen = 5;
        st.maxVestingNameLen = 7;
        st.minVePeriod = 14;
        st.maxVePeriod = 365;
        st.minCliff = 7;

        ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
        vesting[0].name = "12345";
        vesting[0].description = "vesting description";
        vesting[0].allocation = 0;
        vesting[0].start = uint64(block.timestamp + 10 days);
        vesting[0].end = uint64(block.timestamp + 50 days);

        vm.expectRevert(IHost.ZeroValueNotAllowed.selector);
        this.validateVestingListPublic(vestingGoodPhase, vesting, block.timestamp + DEFAULT_CLAIM_OFFSET);
    }

    function tableVestingListGoodPhase_TotalAllocationGe100_Throws(ITokenomics.LifecyclePhase vestingGoodPhase) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minVestingNameLen = 5;
        st.maxVestingNameLen = 7;
        st.minVePeriod = 14;
        st.maxVePeriod = 365;
        st.minCliff = 7;

        ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](2);
        vesting[0].name = "123456";
        vesting[0].description = "vesting description";
        vesting[0].allocation = 99_000;
        vesting[0].start = uint64(block.timestamp + 10 days);
        vesting[0].end = uint64(block.timestamp + 50 days);

        vesting[1].name = "123456";
        vesting[1].description = "vesting 2";
        vesting[1].allocation = 1_000;
        vesting[1].start = uint64(block.timestamp + 15 days);
        vesting[1].end = uint64(block.timestamp + 50 days);

        vm.expectRevert(IHost.TotalAllocationTooHigh.selector);
        this.validateVestingListPublic(vestingGoodPhase, vesting, block.timestamp + DEFAULT_CLAIM_OFFSET);

        vesting[0].allocation = 100_000;
        vesting[1].allocation = 1_000;

        vm.expectRevert(IHost.TotalAllocationTooHigh.selector);
        this.validateVestingListPublic(vestingGoodPhase, vesting, block.timestamp + DEFAULT_CLAIM_OFFSET);
    }

    /// @dev Source data for tableVestingListPositiveBadPhase
    function fixtureVestingBadPhase() public pure returns (ITokenomics.LifecyclePhase[] memory phases) {
        phases = new ITokenomics.LifecyclePhase[](3);
        phases[0] = ITokenomics.LifecyclePhase.LIVE_CLIFF_6;
        phases[1] = ITokenomics.LifecyclePhase.LIVE_VESTING_7;
        phases[2] = ITokenomics.LifecyclePhase.LIVE_8;
    }

    function tableVestingListPositiveBadPhase(ITokenomics.LifecyclePhase vestingBadPhase) public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minVestingNameLen = 5;
        st.maxVestingNameLen = 7;
        st.minVePeriod = 14;
        st.maxVePeriod = 365;
        st.minCliff = 7;

        ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](1);
        vesting[0].name = "vesting name";
        vesting[0].description = "vesting description";
        vesting[0].allocation = 1e18;
        vesting[0].start = uint64(block.timestamp + 10 days);
        vesting[0].end = uint64(block.timestamp + 50 days);

        vm.expectRevert(IHost.TooLateToUpdateVesting.selector);
        this.validateVestingListPublic(vestingBadPhase, vesting, block.timestamp + DEFAULT_CLAIM_OFFSET);
    }

    //endregion ------------------------------------------ Tests for Vesting validation

    //region ------------------------------------------ Tests for Salt validation
    function testValidateSaltSetAllPositive() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        uint daoUid = 7;

        uint16[] memory contractIndices = new uint16[](uint(ITokenomics.ContractIndices.COUNT_CONTRACT_INDICES));
        bytes32[] memory salt = new bytes32[](contractIndices.length);
        for (uint i; i < contractIndices.length; i++) {
            contractIndices[i] = uint16(i);
            salt[i] = bytes32(uint(1 + i));
        }

        this.validateSaltPublic(daoUid, contractIndices, salt);

        // ------------------------- Salts are already used by this DAO
        for (uint i; i < contractIndices.length; i++) {
            $.daoUidBySalt[salt[i]] = daoUid;
        }

        this.validateSaltPublic(daoUid, contractIndices, salt);

        // ------------------------- All contracts has same salt
        for (uint i; i < contractIndices.length; i++) {
            salt[i] = "0x123";
        }

        this.validateSaltPublic(daoUid, contractIndices, salt);
    }

    function testValidateSaltSetAllNegative() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        // ------------------------- Salt is already used by another DAO
        {
            uint16[] memory contractIndices = new uint16[](1);
            bytes32[] memory salt = new bytes32[](contractIndices.length);
            contractIndices[0] = 0;
            salt[0] = "0x123";

            $.daoUidBySalt["0x123"] = 2;

            vm.expectRevert(abi.encodeWithSelector(IHost.SaltAlreadyUsed.selector, bytes32("0x123")));
            this.validateSaltPublic(1, contractIndices, salt);
        }

        // ------------------------- Not consistent length of contractIndices and salt arrays
        {
            uint16[] memory contractIndices = new uint16[](2);
            bytes32[] memory salt = new bytes32[](1);
            contractIndices[0] = 0;
            contractIndices[1] = 1;
            salt[0] = "0x345";

            vm.expectRevert(IHost.IncorrectArrayLengths.selector);
            this.validateSaltPublic(1, contractIndices, salt);
        }

        // ------------------------- Incorrect contract index
        {
            uint16[] memory contractIndices = new uint16[](1);
            bytes32[] memory salt = new bytes32[](1);
            contractIndices[0] = uint16(ITokenomics.ContractIndices.COUNT_CONTRACT_INDICES);
            salt[0] = "0x345";

            vm.expectRevert(abi.encodeWithSelector(IHost.TooHighContractIndex.selector, contractIndices[0]));
            this.validateSaltPublic(1, contractIndices, salt);
        }
    }

    //endregion ------------------------------------------ Tests for Salt validation

    //region ------------------------------------------ Public wrappers for library functions to be able to use vm.expectRevert
    function validateNamingPublic(string memory name, string memory symbol) public view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        HostUpdateLib._validateNaming(name, symbol, st);
    }

    function validateDaoDataPublic(HostLib.DaoDataSegment2 memory dao) public view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        HostUpdateLib._validateDaoData(dao, st);
    }

    function validateDaoParametersPublic(
        uint daoUid,
        ITokenomics.LifecyclePhase phase,
        ITokenomics.DaoParameters memory params
    ) public view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        HostUpdateLib._validateDaoParameters(daoUid, phase, params, st);
    }

    function validateActivityPublic(ITokenomics.Activity[] memory activity_) public pure {
        HostUpdateLib._validateActivity(activity_);
    }

    function validateFundingListPublic(ITokenomics.Funding[] memory funding) public view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        HostUpdateLib._validateFundingList(funding, st);
    }

    function validateFundingPublic(ITokenomics.LifecyclePhase phase, ITokenomics.Funding memory funding) public view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        HostUpdateLib._validateFunding(phase, funding, st);
    }

    function validateVestingListPublic(
        ITokenomics.LifecyclePhase phase,
        ITokenomics.Vesting[] memory vesting,
        uint tgeClaim
    ) public view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        HostUpdateLib._validateVestingList(phase, vesting, st, tgeClaim);
    }

    function validateSaltPublic(uint daoUid, uint16[] memory contractIndices, bytes32[] memory salt_) public view {
        HostUpdateLib._validateSalt(daoUid, contractIndices, salt_);
    }

    function validateChainSettingsPublic(ITokenomics.DaoChainSettings memory st) public pure {
        HostUpdateLib._validateDaoChainSettings(st);
    }

    //endregion ------------------------------------------ Public wrappers for library functions to be able to use vm.expectRevert

    //region ------------------------------------------ Tests for updating logic (except units updating)
    function testUpdateImage() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        ITokenomics.DaoImages memory data = SampleDataLib.getDaoImages();
        bytes memory payload = HostEncodingLib.encodeDaoImages(data, HostEncodingLib.PAYLOAD_API_VERSION);

        vm.expectEmit(false, false, false, true);
        emit IHost.DaoImagesUpdated("ABC", data);

        HostUpdateLib.updateImages(117, payload);

        ITokenomics.DaoImages memory stored = $.daoImages[117];

        assertEq(stored.seedToken, data.seedToken);
        assertEq(stored.tgeToken, data.tgeToken);
        assertEq(stored.token, data.token);
        assertEq(stored.xToken, data.xToken);
        assertEq(stored.daoToken, data.daoToken);
    }

    function testUpdateSocials() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        string[] memory socials = SampleDataLib.getSocialsThree();

        bytes memory payload = HostEncodingLib.encodeSocials(socials);

        vm.expectEmit(false, false, false, true);
        emit IHost.DaoSocialsUpdated("ABC", socials);

        HostUpdateLib.updateSocials(117, payload);

        string[] memory stored = HostLib.getHostStorage().segment3[117].socials;
        assertEq(stored.length, socials.length);
        for (uint i; i < socials.length; i++) {
            assertEq(stored[i], socials[i]);
        }
    }

    function testUpdateFunding() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        ITokenomics.Funding memory data;
        data.start = uint64(block.timestamp + 1 days);
        data.end = uint64(block.timestamp + 10 days);
        data.minRaise = 1e18;
        data.maxRaise = 100e18;
        data.fundingType = ITokenomics.FundingType.TGE_1;

        bytes memory payload = HostEncodingLib.encodeFunding(data, HostEncodingLib.PAYLOAD_API_VERSION);

        vm.expectEmit(false, false, false, true);
        emit IHost.DaoFundingUpdated(117, data);

        HostUpdateLib.updateFunding(117, payload);

        bytes32 fundingId = HostLib.getKey(117, uint(data.fundingType));
        ITokenomics.Funding memory stored = $.funding[fundingId];

        assertEq(stored.start, data.start);
        assertEq(stored.end, data.end);
        assertEq(stored.minRaise, data.minRaise);
        assertEq(stored.maxRaise, data.maxRaise);
        assertEq(uint(stored.fundingType), uint(data.fundingType));

        ITokenomics.FundingType[] memory list = $.segment3[117].funding;
        assertEq(list.length, 1);
        assertEq(uint(list[0]), uint(data.fundingType));
    }

    function testUpdateVesting() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        ITokenomics.Vesting[] memory vesting = new ITokenomics.Vesting[](2);
        vesting[0].name = "vesting name";
        vesting[0].description = "vesting description";
        vesting[0].allocation = 1e18;
        vesting[0].start = uint64(block.timestamp + 1 days);
        vesting[0].end = uint64(block.timestamp + 50 days);

        vesting[1].name = "vesting 1";
        vesting[1].description = "vesting 2";
        vesting[1].allocation = 2e18;
        vesting[1].start = uint64(block.timestamp + 2 days);
        vesting[1].end = uint64(block.timestamp + 60 days);

        bytes memory payload = HostEncodingLib.encodeVesting(vesting, HostEncodingLib.PAYLOAD_API_VERSION);

        vm.expectEmit(false, false, false, true);
        emit IHost.DaoVestingUpdated(117, vesting);

        HostUpdateLib.updateVesting(117, payload);

        uint count = HostLib.getHostStorage().segment3[117].countVesting;
        assertEq(count, vesting.length);

        for (uint i = 0; i < vesting.length; i++) {
            bytes32 key = HostLib.getIndexKey(117, i);
            HostLib.VestingLocal memory stored = $.vesting[key];
            assertEq(stored.name, vesting[i].name);
            assertEq(stored.allocation, vesting[i].allocation);
            assertEq(stored.start, vesting[i].start);
            assertEq(stored.end, vesting[i].end);
        }
    }

    function testUpdateNaming() public {
        MockHostBridge mockedBridge = new MockHostBridge();
        {
            IHost.HostChainSettings storage chainSettings = HostConfigLib.getHostChainSettings();
            chainSettings.hostBridge = address(mockedBridge);
        }

        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";
        $.segment2[117].name = "Old Name";

        ITokenomics.DaoNames memory data;
        data.name = "New DAO Name";
        data.symbol = "XYZ";

        bytes memory payload = HostEncodingLib.encodeDaoNames(data, HostEncodingLib.PAYLOAD_API_VERSION);

        vm.expectEmit(false, false, false, true);
        emit IHost.DaoNamingUpdated(117, data);

        HostUpdateLib.updateNaming(117, payload);

        // storage checks
        assertEq($.segment2[117].symbol, data.symbol);
        assertEq($.segment2[117].name, data.name);
        assertEq($.daoUids["ABC"], 0);
        assertEq($.daoUids["XYZ"], 117);

        bytes memory message = mockedBridge.receivedMessages(uint(IHost.CrossChainMessages.DAO_RENAME_SYMBOL_1));
        assertTrue(message.length != 0, "some message was sent to other chains");
    }

    function testUpdateDaoParameters() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        ITokenomics.DaoParameters memory data;
        data.pvpFee = 500;
        data.vePeriod = 30;

        bytes memory payload = HostEncodingLib.encodeDaoParameters(data, HostEncodingLib.PAYLOAD_API_VERSION);

        vm.expectEmit(false, false, false, true);
        emit IHost.DaoParametersUpdated(117, data);

        HostUpdateLib.updateDaoParameters(117, payload);

        ITokenomics.DaoParameters memory stored = $.daoParameters[117];
        assertEq(stored.pvpFee, data.pvpFee);
        assertEq(stored.vePeriod, data.vePeriod);
    }

    function testUpdateSalt() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        uint16[] memory contractIndices = new uint16[](2);
        bytes32[] memory salt = new bytes32[](2);
        contractIndices[0] = 0;
        contractIndices[1] = 1;
        salt[0] = bytes32(uint(0x123));
        salt[1] = bytes32(uint(0x456));

        bytes memory payload = HostEncodingLib.encodeSalt(contractIndices, salt, HostEncodingLib.PAYLOAD_API_VERSION);

        vm.expectEmit(false, false, false, true);
        emit IHost.SaltUpdated(117, contractIndices, salt);

        HostUpdateLib.updateSalt(117, payload);

        for (uint i = 0; i < contractIndices.length; i++) {
            bytes32 key = HostLib.getKey(117, contractIndices[i]);
            assertEq($.salt[key], salt[i]);
            assertEq($.daoUidBySalt[salt[i]], 117);
        }
    }

    function testUpdateDaoChainSettings() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        ITokenomics.DaoChainSettings memory settings;
        settings.bbRate = 100;

        bytes memory payload = HostEncodingLib.encodeDaoChainSettings(settings, HostEncodingLib.PAYLOAD_API_VERSION);

        vm.expectEmit(false, false, false, true);
        emit IHost.DaoChainSettingsUpdated(117, settings);

        HostUpdateLib.updateDaoChainSettings(117, payload);

        bytes32 storedHash = keccak256(abi.encode($.chainSettings[117]));
        bytes32 expectedHash = keccak256(abi.encode(settings));
        assertEq(storedHash, expectedHash);

        assertEq($.chainSettings[117].bbRate, settings.bbRate);
    }

    //endregion ------------------------------------------ Tests for updating logic (except units updating)

    //region ------------------------------------------ Tests for updating list of units
    function testUpdateUnits_Create() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        // prepare units to create
        IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](2);
        units[0].unitId = "unitA";
        units[0].developerUid = "10";
        units[1].unitId = "unitB";
        units[1].developerUid = "20";

        IDAOData.UnitEmitData[] memory metadata = new IDAOData.UnitEmitData[](2);
        metadata[0].name = "aaa";
        metadata[1].name = "bbb";

        // expect two instant update events (one per unit)
        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitUpdatedInstantly(117, units[0].unitId, metadata[0]);
        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitUpdatedInstantly(117, units[1].unitId, metadata[1]);

        // call library (proposalId == 0 => instant)
        HostUpdateLib.updateUnits(117, units, bytes32(0), metadata);

        // storage checks
        string[] memory ids = $.segment2[117].unitIds;
        assertEq(ids.length, 2);
        assertEq(ids[0], "unitA");
        assertEq(ids[1], "unitB");

        bytes32 keyA = HostLib.getUnitKey(117, "unitA");
        HostLib.UnitLocal storage storedA = $.units[keyA];
        assertEq(storedA.developerUid, "10");
        assertEq(storedA.unitId, "unitA");

        bytes32 keyB = HostLib.getUnitKey(117, "unitB");
        HostLib.UnitLocal storage storedB = $.units[keyB];
        assertEq(storedB.developerUid, "20");
        assertEq(storedB.unitId, "unitB");
    }

    function testUpdateUnits_Update() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        // pre-populate existing unit
        $.segment2[117].unitIds = new string[](1);
        $.segment2[117].unitIds[0] = "unitX";
        bytes32 existingKey = HostLib.getUnitKey(117, "unitX");
        $.units[existingKey].daoUid = 117;
        $.units[existingKey].unitId = "unitX";
        $.units[existingKey].developerUid = "42";

        // prepare units array with same id but different developerUid
        IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](1);
        units[0].unitId = "unitX";
        units[0].developerUid = "99";

        IDAOData.UnitEmitData[] memory metadata = new IDAOData.UnitEmitData[](1);
        metadata[0].name = "aaa";

        // expect single instant update event
        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitUpdatedInstantly(117, units[0].unitId, metadata[0]);

        HostUpdateLib.updateUnits(117, units, bytes32(0), metadata);

        // check that developerUid updated and unitIds unchanged
        string[] memory ids = $.segment2[117].unitIds;
        assertEq(ids.length, 1);
        assertEq(ids[0], "unitX");

        HostLib.UnitLocal storage stored = $.units[existingKey];
        assertEq(stored.developerUid, "99");
        assertEq(stored.unitId, "unitX");
    }

    function testUpdateUnits_DeleteAll() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        // pre-populate several units
        $.segment2[117].unitIds = new string[](3);
        $.segment2[117].unitIds[0] = "u1";
        $.segment2[117].unitIds[1] = "u2";
        $.segment2[117].unitIds[2] = "u3";

        bytes32 k1 = HostLib.getUnitKey(117, "u1");
        bytes32 k2 = HostLib.getUnitKey(117, "u2");
        bytes32 k3 = HostLib.getUnitKey(117, "u3");
        $.units[k1].daoUid = 117;
        $.units[k2].daoUid = 117;
        $.units[k3].daoUid = 117;

        // Expect delete events for each existing unit (proposalId set to 0 here as passed through)
        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitDeleted(117, "u1", bytes32(0));
        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitDeleted(117, "u2", bytes32(0));
        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitDeleted(117, "u3", bytes32(0));

        // call with empty units -> all should be deleted
        IDAOData.UnitDataInput[] memory units;
        IDAOData.UnitEmitData[] memory metadata;

        HostUpdateLib.updateUnits(117, units, bytes32(0), metadata);

        // unitIds should be empty and storage entries cleared
        assertEq($.segment2[117].unitIds.length, 0);
        // deleted structs reset to defaults
        assertEq($.units[k1].daoUid, 0);
        assertEq($.units[k2].daoUid, 0);
        assertEq($.units[k3].daoUid, 0);
    }

    function testUpdateUnits_Mixed_DeleteUpdateCreate_ByProposal() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.daoUids["ABC"] = 117;
        $.segment2[117].symbol = "ABC";

        // pre-populate existing units: a, b, c
        $.segment2[117].unitIds = new string[](3);
        $.segment2[117].unitIds[0] = "a";
        $.segment2[117].unitIds[1] = "b";
        $.segment2[117].unitIds[2] = "c";

        bytes32 ka = HostLib.getUnitKey(117, "a");
        bytes32 kb = HostLib.getUnitKey(117, "b");
        bytes32 kc = HostLib.getUnitKey(117, "c");
        $.units[ka].daoUid = 117;
        $.units[ka].unitId = "a";
        $.units[ka].developerUid = "1";
        $.units[kb].daoUid = 117;
        $.units[kb].unitId = "b";
        $.units[kb].developerUid = "2";
        $.units[kc].daoUid = 117;
        $.units[kc].unitId = "c";
        $.units[kc].developerUid = "3";

        // New list: keep 'b' (but change developerUid), add 'd' and 'e' (new), drop 'a' and 'c'
        IDAOData.UnitDataInput[] memory units = new IDAOData.UnitDataInput[](3);
        units[0].unitId = "b";
        units[0].developerUid = "22"; // update existing
        units[1].unitId = "d";
        units[1].developerUid = "44"; // new
        units[2].unitId = "e";
        units[2].developerUid = "55"; // new

        IDAOData.UnitEmitData[] memory metadata = new IDAOData.UnitEmitData[](3);
        metadata[0].name = "meta b";
        metadata[1].name = "meta d";
        metadata[2].name = "meta e";

        bytes32 proposalId = bytes32("0x123");

        // Expect deletions first (a,c), then three by-proposal updates (b,d,e) in order
        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitDeleted(117, "a", proposalId);
        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitDeleted(117, "c", proposalId);

        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitUpdatedByProposal(117, units[0].unitId, proposalId);
        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitUpdatedByProposal(117, units[1].unitId, proposalId);
        vm.expectEmit(false, false, false, true);
        emit IHost.DaoUnitUpdatedByProposal(117, units[2].unitId, proposalId);

        HostUpdateLib.updateUnits(117, units, proposalId, metadata);

        {
            string[] memory ids = $.segment2[117].unitIds;
            assertEq(ids.length, 3);
            assertEq(ids[0], "b");
            assertEq(ids[1], "d");
            assertEq(ids[2], "e");
        }

        {
            // 'b' updated
            bytes32 kbNew = HostLib.getUnitKey(117, "b");
            HostLib.UnitLocal storage storedB = $.units[kbNew];
            assertEq(storedB.developerUid, "22");
        }

        {
            // 'd' and 'e' created
            bytes32 kd = HostLib.getUnitKey(117, "d");
            bytes32 ke = HostLib.getUnitKey(117, "e");
            HostLib.UnitLocal storage storedD = $.units[kd];
            HostLib.UnitLocal storage storedE = $.units[ke];
            assertEq(storedD.developerUid, "44");
            assertEq(storedD.unitId, "d");
            assertEq(storedE.developerUid, "55");
            assertEq(storedE.unitId, "e");
        }

        // 'a' and 'c' removed
        assertEq($.units[ka].daoUid, 0);
        assertEq($.units[kc].daoUid, 0);
    }

    //endregion ------------------------------------------ Tests for updating list of units

    //region ------------------------------------------ Internal logic
    function _createAuthority() internal returns (IAuthority) {
        vm.prank(multisig);
        ProxyFactory proxyFactory = new ProxyFactory();

        MockHost _host = new MockHost();

        Authority _authority = new Authority(multisig, address(_host), address(proxyFactory));

        vm.prank(multisig);
        proxyFactory.setWhitelisted(address(_authority), true);

        return _authority;
    }

    //endregion ------------------------------------------ Internal logic
}
