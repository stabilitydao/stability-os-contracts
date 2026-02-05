// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
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
