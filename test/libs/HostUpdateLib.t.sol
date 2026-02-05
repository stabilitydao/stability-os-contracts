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
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {HostUtilsLib} from "../utils/HostUtilsLib.sol";

contract HostUpdateLibTest is Test {
    MockERC20 internal exchangeAsset;

    /// @dev msg.sender (it cannot be changed by vm.prank in library calls)
    address internal user;
    address public multisig;
    IAuthority public authority;

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

    function testValidateActivityPositive() public {
        uint count = uint(ITokenomics.Activity.COUNT_ACTIVITY);
        {   // all activity
            ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](count);
            for (uint i = 0; i < count; i++) {
                activity[i] = ITokenomics.Activity(i);
            }
            this.validateActivityPublic(activity);
        }

        {   // empty activity
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
        {   // builder alone
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

    function testValidateDaoParametersPositive() public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        st.minPvPFee = 100;
        st.maxPvPFee = 1000;
        st.minVePeriod = 14;
        st.maxVePeriod = 365;

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 500;
            params.vePeriod = 30;
            this.validateDaoParametersPublic(params);
        }

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 100;
            params.vePeriod = 14;
            this.validateDaoParametersPublic(params);
        }

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 1000;
            params.vePeriod = 365;
            this.validateDaoParametersPublic(params);
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
            this.validateDaoParametersPublic(params);
        }

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 1001;
            params.vePeriod = 30;
            vm.expectRevert(abi.encodeWithSelector(IHost.PvPFee.selector, uint(1001)));
            this.validateDaoParametersPublic(params);
        }

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 500;
            params.vePeriod = 13;
            vm.expectRevert(abi.encodeWithSelector(IHost.VePeriod.selector, uint(13)));
            this.validateDaoParametersPublic(params);
        }

        {
            ITokenomics.DaoParameters memory params;
            params.pvpFee = 500;
            params.vePeriod = 366;
            vm.expectRevert(abi.encodeWithSelector(IHost.VePeriod.selector, uint(366)));
            this.validateDaoParametersPublic(params);
        }

    }

    function testValidateFundingListPositive() public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;

        {
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
            funding[0].start = uint64(block.timestamp + 1 days);
            funding[0].end = uint64(block.timestamp + 10 days);
            funding[0].minRaise = 1e18;
            funding[0].maxRaise = 100e18;
            funding[0].fundingType = ITokenomics.FundingType.TGE_1;

            this.validateFundingListPublic(funding);
        }

        {
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](2);
            funding[0].start = uint64(block.timestamp + 1 days);
            funding[0].end = uint64(block.timestamp + 10 days);
            funding[0].minRaise = 1e18;
            funding[0].maxRaise = 100e18;
            funding[0].fundingType = ITokenomics.FundingType.TGE_1;

            funding[1].start = uint64(block.timestamp + 1 days);
            funding[1].end = uint64(block.timestamp + 10 days);
            funding[1].minRaise = 1e18;
            funding[1].maxRaise = 100e18;
            funding[1].fundingType = ITokenomics.FundingType.SEED_0;

            this.validateFundingListPublic(funding);
        }
    }

    function testValidateFundingListNegative() public {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();

        st.minFundingDuration = 7 days;
        st.maxFundingDuration = 90 days;

        {
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
            funding[0].start = uint64(block.timestamp + 1 days);
            funding[0].end = 0; // (!)
            funding[0].minRaise = 1e18;
            funding[0].maxRaise = 100e18;
            funding[0].fundingType = ITokenomics.FundingType.TGE_1;

            vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingPeriod.selector));
            this.validateFundingListPublic(funding);
        }

        {
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
            funding[0].start = uint64(block.timestamp + 1 days);
            funding[0].end = uint64(block.timestamp + 1 days);
            funding[0].minRaise = 1e18;
            funding[0].maxRaise = 100e18;
            funding[0].fundingType = ITokenomics.FundingType.TGE_1;

            vm.expectRevert(abi.encodeWithSelector(IHost.InvalidFundingPeriod.selector));
            this.validateFundingListPublic(funding);
        }

        {
            ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](2);
            funding[0].start = uint64(block.timestamp + 1 days);
            funding[0].end = uint64(block.timestamp + 10 days);
            funding[0].minRaise = 1e18;
            funding[0].maxRaise = 100e18;
            funding[0].fundingType = ITokenomics.FundingType.TGE_1;

            funding[1].start = uint64(block.timestamp + 1 days);
            funding[1].end = uint64(block.timestamp + 10 days);
            funding[1].minRaise = 1e18;
            funding[1].maxRaise = 100e18;
            funding[1].fundingType = ITokenomics.FundingType.SEED_0;

            this.validateFundingListPublic(funding);
        }
    }

    //endregion ------------------------------------------ Tests for validation

    //region ------------------------------------------ Public wrappers for library functions to be able to use vm.expectRevert
    function validateNamingPublic(string memory name, string memory symbol) public view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        HostUpdateLib._validateNaming(name, symbol, st);
    }

    function validateDaoDataPublic(HostLib.DaoDataSegment2 memory dao) public view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        HostUpdateLib._validateDaoData(dao, st);
    }

    function validateDaoParametersPublic(ITokenomics.DaoParameters memory params) public view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        HostUpdateLib._validateDaoParameters(params, st);
    }

    function validateActivityPublic(ITokenomics.Activity[] memory activity_) public view {
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
        ITokenomics.Vesting[] memory vesting
    ) public view {
        IHost.HostSettings storage st = HostConfigLib.getHostGlobalSettings();
        HostUpdateLib._validateVestingList(phase, vesting, st);
    }

    function validateSaltPublic(uint daoUid, uint16[] memory contractIndices, bytes32[] memory salt_) public view {
        HostUpdateLib._validateSalt(daoUid, contractIndices, salt_);
    }

    //endregion ------------------------------------------ Public wrappers for library functions to be able to use vm.expectRevert

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
