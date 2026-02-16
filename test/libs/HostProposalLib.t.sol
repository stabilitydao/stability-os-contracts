// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

//import {console} from "forge-std/console.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";
import {Test} from "forge-std/Test.sol";
import {MockHost} from "../mocks/MockHost.sol";
import {Authority} from "../../src/Authority.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {HostProposalLib} from "../../src/libs/HostProposalLib.sol";
import {HostConfigLib} from "../../src/libs/HostConfigLib.sol";
import {HostLib} from "../../src/libs/HostLib.sol";
import {HostEncodingLib} from "../../src/libs/HostEncodingLib.sol";
import {IAuthority} from "../../src/interfaces/IAuthority.sol";
import {IHost} from "../../src/interfaces/IHost.sol";
import {IProxyFactory} from "../../src/interfaces/IProxyFactory.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {IHosted} from "../../src/interfaces/IHosted.sol";
import {ISeedToken} from "../../src/interfaces/ISeedToken.sol";
import {SeedToken} from "../../src/tokenomics/SeedToken.sol";
import {SampleDataLib} from "../utils/SampleDataLib.sol";

contract HostProposalLibTest is Test {
    MockERC20 internal exchangeAsset;

    uint64 internal constant MINTER_ROLE = 123456;

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

    //region ------------------------------------------ Tests for main logic

    //endregion ------------------------------------------ Tests for main logic

    //region ------------------------------------------ Tests for proposal utils
    function testGetActionParams() public pure {
        {
            HostProposalLib.ActionParams memory p =
                HostProposalLib._getActionParams(ITokenomics.DAOAction.UPDATE_UNITS_3, true, true);
            assertEq(uint(p.action), uint(ITokenomics.DAOAction.UPDATE_UNITS_3), "UPDATE_UNITS_3 is correct");
            assertTrue(p.validationRequired, "validation is required 1");
            assertFalse(p.votingRequired, "voting is not required 1");
        }

        {
            HostProposalLib.ActionParams memory p =
                HostProposalLib._getActionParams(ITokenomics.DAOAction.UPDATE_FUNDING_4, false, true);
            assertEq(uint(p.action), uint(ITokenomics.DAOAction.UPDATE_FUNDING_4), "UPDATE_FUNDING_4 is correct");
            assertTrue(p.validationRequired, "validation is required 2");
            assertTrue(p.votingRequired, "voting is required 2");
        }

        {
            HostProposalLib.ActionParams memory p =
                HostProposalLib._getActionParams(ITokenomics.DAOAction.UPDATE_IMAGES_0, false, false);
            assertEq(uint(p.action), uint(ITokenomics.DAOAction.UPDATE_IMAGES_0), "UPDATE_IMAGES_0 is correct");
            assertFalse(p.validationRequired, "validation is not required 2");
            assertTrue(p.votingRequired, "voting is required 2");
        }
    }

    function testGetBridgedActionParams() public pure {
        IHost.BridgedActions[9] memory bridgedActions = [
            IHost.BridgedActions.UNKNOWN_0,
            IHost.BridgedActions.BRIDGE_DAO_1,
            IHost.BridgedActions.SET_BRIDGED_UNITS_2,
            IHost.BridgedActions.RESERVED_3,
            IHost.BridgedActions.SET_DAO_PARAMS_4,
            IHost.BridgedActions.SET_SALTS_5,
            IHost.BridgedActions.UPDATE_CHAIN_SETTINGS_6,
            IHost.BridgedActions.BRIDGE_DAO_WITH_DEPLOYMENTS_7,
            IHost.BridgedActions.DEPLOYMENTS_8
        ];

        ITokenomics.DAOAction[10] memory actions = [
            ITokenomics.DAOAction.UPDATE_IMAGES_0,
            ITokenomics.DAOAction.UPDATE_SOCIALS_1,
            ITokenomics.DAOAction.UPDATE_NAMING_2,
            ITokenomics.DAOAction.UPDATE_UNITS_3,
            ITokenomics.DAOAction.UPDATE_FUNDING_4,
            ITokenomics.DAOAction.UPDATE_VESTING_5,
            ITokenomics.DAOAction.UPDATE_DAO_PARAMETERS_6,
            ITokenomics.DAOAction.UPDATE_SALT_7,
            ITokenomics.DAOAction.UPDATE_DAO_CHAIN_SETTINGS_8,
            ITokenomics.DAOAction.UPDATE_BRIDGED_DAO_9
        ];
        for (uint i; i < actions.length; i++) {
            for (uint j; j < bridgedActions.length; j++) {
                HostProposalLib.ActionParams memory p =
                    HostProposalLib._getBridgedActionParams(actions[i], uint16(bridgedActions[j]));
                assertEq(uint(p.action), uint(actions[i]), "action is correct");
                assertTrue(p.votingRequired, "voting is always required");
                assertEq(
                    p.validationRequired,
                    IHost.BridgedActions.SET_SALTS_5 == bridgedActions[j]
                        || IHost.BridgedActions.BRIDGE_DAO_1 == bridgedActions[j],
                    "validation is required for bridged actions 1 and 5 only"
                );
            }
        }
    }

    function testProposeAction() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment3[16308565].initialChain = block.chainid;

        HostProposalLib.ActionParams memory p =
            HostProposalLib._getActionParams(ITokenomics.DAOAction.UPDATE_IMAGES_0, false, true);
        bytes memory payload = _getSampleProposalPayload();

        vm.recordLogs();
        bytes32 proposalId = HostProposalLib._proposeAction(16308565, payload, p);

        assertEq($.daoProposals[16308565].length, 1, "proposal is added to daoProposals 1");
        assertEq($.daoProposals[16308565][0], proposalId, "proposal is added to daoProposals 2");

        HostLib.ProposalData storage proposal = $.proposals[proposalId];

        {
            bytes32 expectedPayloadHash = keccak256(payload);
            assertEq(proposal.id, proposalId, "proposal ID is correct");
            assertEq(proposal.daoUid, 16308565, "proposal daoUid is correct");
            assertEq(proposal.payloadHash, expectedPayloadHash, "payload hash is correct");
        }
        {
            HostLib.ProposalHeader memory proposalHeader = HostLib.unpackProposalHeader(proposal.proposalHeader);
            assertEq(
                uint(proposalHeader.action), uint(ITokenomics.DAOAction.UPDATE_IMAGES_0), "proposal action is correct"
            );
            assertTrue(proposalHeader.validationRequired, "proposal validationRequired is correct");
            assertTrue(proposalHeader.votingRequired, "proposal votingRequired is correct");
            assertTrue(proposalHeader.validationStatus == ITokenomics.ValidationStatus.NONE_0, "validationStatus");
            assertTrue(proposalHeader.status == ITokenomics.VotingStatus.VOTING_0, "status");
            assertEq(proposalHeader.created, block.timestamp, "created is set");
        }
    }

    function testProposeActionNotInitialChain() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment3[16308565].initialChain = block.chainid + 1; // (!) We try to call proposeAction on not initial chain

        HostProposalLib.ActionParams memory p =
            HostProposalLib._getActionParams(ITokenomics.DAOAction.UPDATE_IMAGES_0, false, true);
        bytes memory payload = _getSampleProposalPayload();

        vm.expectRevert(IHost.NotInitialChain.selector);
        this.proposeAction(16308565, payload, p);
    }

    //endregion ------------------------------------------ Tests for proposal utils

    //region ------------------------------------------ Check user power tests
    function testCheckUserPower_Draft_Success() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment2[1].phase = ITokenomics.LifecyclePhase.DRAFT_0;

        // Proposal that requires voting cannot be created on DRAFT stage
        // Anyway, proposal that requires validation only can be created
        // No user power is required in that case, anybody can create such proposal
        this._checkUserPowerPublic(1); // no revert
    }

    function testCheckUserPower_Inception_Success() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment2[1].phase = ITokenomics.LifecyclePhase.INCEPTION_1;

        // Proposal that requires voting cannot be created on INCEPTION stage
        // Anyway, proposal that requires validation only can be created
        // No user power is required in that case, anybody can create such proposal
        this._checkUserPowerPublic(1); // no revert
    }

    // todo: implement _checkUserPowerPublic for LIVE_CLIFF_5 and other phases
    function testCheckUserPower_LiveCliff_NotImplemented() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();
        $.segment2[1].phase = ITokenomics.LifecyclePhase.LIVE_CLIFF_6;

        vm.expectRevert(IHost.NotImplemented.selector);
        this._checkUserPowerPublic(1); // no revert
    }

    function fixtureSeedPowerPhase() public pure returns (ITokenomics.LifecyclePhase[] memory phases) {
        phases = new ITokenomics.LifecyclePhase[](uint(ITokenomics.LifecyclePhase.LIVE_CLIFF_6) - 2);
        for (uint i = 2; i < uint(ITokenomics.LifecyclePhase.LIVE_CLIFF_6); i++) {
            phases[i - 2] = ITokenomics.LifecyclePhase(i);
        }
    }

    function testCheckUserPower_UserHasEnoughSeedPower_Success() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ISeedToken seedToken = _deploySeedToken(1);
        $.deployments[1].seedToken = address(seedToken);
        _setupSeedTokenMinter(address(this), address(seedToken));

        seedToken.mint(address(this), 2_000); // 20%
        seedToken.mint(makeAddr("other user"), 8_000); // 80%
        ITokenomics.LifecyclePhase[] memory phases = fixtureSeedPowerPhase();
        for (uint i; i < phases.length; i++) {
            ITokenomics.LifecyclePhase seedPowerPhase = phases[i];
            $.segment2[1].phase = ITokenomics.LifecyclePhase(seedPowerPhase);
            $.daoParameters[1].proposalThreshold = 20_000; // 20%, user has 20%
            this._checkUserPowerPublic(1); // no revert

            $.segment2[1].phase = ITokenomics.LifecyclePhase(seedPowerPhase);
            $.daoParameters[1].proposalThreshold = 10_000; // 10%, user has 20%
            this._checkUserPowerPublic(1); // no revert
        }
    }

    function testCheckUserPower_SeedZeroTotalSupply_Revert() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ISeedToken seedToken = _deploySeedToken(1);
        $.deployments[1].seedToken = address(seedToken);
        _setupSeedTokenMinter(address(this), address(seedToken));

        ITokenomics.LifecyclePhase[] memory phases = fixtureSeedPowerPhase();
        for (uint i; i < phases.length; i++) {
            ITokenomics.LifecyclePhase seedPowerPhase = phases[i];

            $.segment2[1].phase = ITokenomics.LifecyclePhase(seedPowerPhase);
            $.daoParameters[1].proposalThreshold = 21_000; // 21%, user has 20%, not enough

            vm.expectRevert(IHost.NotEnoughUserPower.selector);
            this._checkUserPowerPublic(1);
        }
    }

    function testCheckUserPower_UserHasNotEnoughSeedPower_Revert() public {
        HostLib.HostStorage storage $ = HostLib.getHostStorage();

        ISeedToken seedToken = _deploySeedToken(1);
        $.deployments[1].seedToken = address(seedToken);
        _setupSeedTokenMinter(address(this), address(seedToken));

        seedToken.mint(address(this), 2_000); // 20%
        seedToken.mint(makeAddr("other user"), 8_000); // 80%

        ITokenomics.LifecyclePhase[] memory phases = fixtureSeedPowerPhase();
        for (uint i; i < phases.length; i++) {
            ITokenomics.LifecyclePhase seedPowerPhase = phases[i];

            $.segment2[1].phase = ITokenomics.LifecyclePhase(seedPowerPhase);
            $.daoParameters[1].proposalThreshold = 21_000; // 21%, user has 20%, not enough

            vm.expectRevert(IHost.NotEnoughUserPower.selector);
            this._checkUserPowerPublic(1);
        }
    }

    //endregion ------------------------------------------ Check user power tests

    //region ------------------------------------------ Tests for _isActionRunnable
    function testIsActionRunnable_NoValidationNoVoting_ReturnFalse() public view {
        HostLib.ProposalHeader memory header = HostLib.ProposalHeader({
            action: ITokenomics.DAOAction.UPDATE_IMAGES_0,
            validationRequired: false,
            votingRequired: false,
            validationStatus: ITokenomics.ValidationStatus.NONE_0,
            status: ITokenomics.VotingStatus.VOTING_0,
            created: uint64(block.timestamp)
        });
        assertFalse(
            HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VOTING_0), "voting is not required"
        );
        assertFalse(
            HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1), "validation is not required"
        );
    }

    function testIsActionRunnable_ValidationNoVoting() public view {
        HostLib.ProposalHeader memory header = HostLib.ProposalHeader({
            action: ITokenomics.DAOAction.UPDATE_IMAGES_0,
            validationRequired: true,
            votingRequired: false,
            validationStatus: ITokenomics.ValidationStatus.NONE_0,
            status: ITokenomics.VotingStatus.VOTING_0,
            created: uint64(block.timestamp)
        });
        assertTrue(
            HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1), "validation => action"
        );

        assertFalse(
            HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VOTING_0), "voting is not required"
        );

        header.validationStatus = ITokenomics.ValidationStatus.APPROVED_1;
        assertFalse(HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1), "already validated");

        header.validationStatus = ITokenomics.ValidationStatus.REJECTED_2;
        assertFalse(HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1), "already validated");
    }

    function testIsActionRunnable_NoValidationVoting() public view {
        HostLib.ProposalHeader memory header = HostLib.ProposalHeader({
            action: ITokenomics.DAOAction.UPDATE_IMAGES_0,
            validationRequired: false,
            votingRequired: true,
            validationStatus: ITokenomics.ValidationStatus.NONE_0,
            status: ITokenomics.VotingStatus.VOTING_0,
            created: uint64(block.timestamp)
        });
        assertTrue(HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VOTING_0), "voting => action");

        assertFalse(
            HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1), "validation is not required"
        );

        header.status = ITokenomics.VotingStatus.APPROVED_1;
        assertFalse(HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1), "already voted");

        header.status = ITokenomics.VotingStatus.REJECTED_2;
        assertFalse(HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1), "already voted");
    }

    function testIsActionRunnable_ValidationVoting() public view {
        // ------------------------------- both validation and voting not performed
        {
            HostLib.ProposalHeader memory header = HostLib.ProposalHeader({
                action: ITokenomics.DAOAction.UPDATE_IMAGES_0,
                validationRequired: true,
                votingRequired: true,
                validationStatus: ITokenomics.ValidationStatus.NONE_0,
                status: ITokenomics.VotingStatus.VOTING_0,
                created: uint64(block.timestamp)
            });
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VOTING_0),
                "voting cannot be performed before validation"
            );
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1),
                "validation doesn't perform action, it just approves for voting"
            );
        }

        // ------------------------------- validation is performed, voting not performed
        {
            HostLib.ProposalHeader memory header = HostLib.ProposalHeader({
                action: ITokenomics.DAOAction.UPDATE_IMAGES_0,
                validationRequired: true,
                votingRequired: true,
                validationStatus: ITokenomics.ValidationStatus.APPROVED_1,
                status: ITokenomics.VotingStatus.VOTING_0,
                created: uint64(block.timestamp)
            });
            assertTrue(HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VOTING_0), "voting => action");
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1),
                "validation already performed"
            );

            header.validationStatus = ITokenomics.ValidationStatus.REJECTED_2;
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VOTING_0),
                "voting cannot be performed if proposal is rejected"
            );
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1),
                "validation already performed"
            );
        }

        // ------------------------------- validation and voting are performed
        {
            HostLib.ProposalHeader memory header = HostLib.ProposalHeader({
                action: ITokenomics.DAOAction.UPDATE_IMAGES_0,
                validationRequired: true,
                votingRequired: true,
                validationStatus: ITokenomics.ValidationStatus.APPROVED_1,
                status: ITokenomics.VotingStatus.APPROVED_1,
                created: uint64(block.timestamp)
            });
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VOTING_0), "voting already performed"
            );
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1),
                "validation already performed"
            );

            header.status = ITokenomics.VotingStatus.REJECTED_2;
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VOTING_0), "voting already rejected"
            );
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1),
                "validation already performed"
            );
        }

        // ------------------------------- validation not performed, voting are performed (not real case)
        {
            HostLib.ProposalHeader memory header = HostLib.ProposalHeader({
                action: ITokenomics.DAOAction.UPDATE_IMAGES_0,
                validationRequired: true,
                votingRequired: true,
                validationStatus: ITokenomics.ValidationStatus.NONE_0,
                status: ITokenomics.VotingStatus.APPROVED_1,
                created: uint64(block.timestamp)
            });
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VOTING_0), "voting already performed"
            );
            assertTrue(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1), "validation => true"
            );

            header.status = ITokenomics.VotingStatus.REJECTED_2;
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VOTING_0), "voting already rejected"
            );
            assertFalse(
                HostProposalLib._isActionRunnable(header, IHost.ValidationMethod.VALIDATION_1),
                "validation cannot perform action if proposal is rejected"
            );
        }
    }

    //endregion ------------------------------------------ Tests for _isActionRunnable

    //region ------------------------------------------ Public functions to be able to test expectRevert on library calls
    function proposeAction(
        uint daoUid,
        bytes memory payload,
        HostProposalLib.ActionParams memory params_
    ) public returns (bytes32) {
        return HostProposalLib._proposeAction(daoUid, payload, params_);
    }

    //endregion ------------------------------------------ Public functions to be able to test expectRevert on library calls

    //region ------------------------------------------ Internal logic
    function _getSampleProposalPayload() internal pure returns (bytes memory) {
        ITokenomics.DaoImages memory data = SampleDataLib.getDaoImages();

        return HostEncodingLib.encodeDaoImages(data, HostEncodingLib.PAYLOAD_API_VERSION);
    }

    function _createAuthority() internal returns (IAuthority) {
        vm.prank(multisig);
        ProxyFactory proxyFactory = new ProxyFactory();

        MockHost _host = new MockHost();

        Authority _authority = new Authority(multisig, address(_host), address(proxyFactory));

        vm.prank(multisig);
        proxyFactory.setWhitelisted(address(_authority), true);

        return _authority;
    }

    function _setupSeedTokenMinter(address minter, address seedToken) internal {
        // set up OS as operator for all restricted functions
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(SeedToken.mint.selector);

        vm.prank(multisig);
        IAuthority(authority).setTargetFunctionRole(seedToken, selectors, MINTER_ROLE);

        vm.prank(multisig);
        IAuthority(authority).grantRole(MINTER_ROLE, address(minter), 0);
    }

    function _deploySeedToken(uint daoUid) internal returns (ISeedToken _seedToken) {
        address logic = address(new SeedToken());
        address proxyFactory = authority.PROXY_FACTORY();
        _seedToken = ISeedToken(IProxyFactory(proxyFactory).predictAddress("0x375654"));

        vm.prank(multisig);
        authority.execute(
            proxyFactory,
            abi.encodeCall(
                IProxyFactory.create2NewProxy,
                ("0x375654", logic, abi.encodeCall(IHosted.initialize, (address(authority), abi.encode(daoUid))))
            )
        );
    }

    //endregion ------------------------------------------ Internal logic

    //region ------------------------------------------ External access to library functions
    function _checkUserPowerPublic(uint daoUid) public view {
        HostProposalLib._checkUserPower(daoUid);
    }

    //endregion ------------------------------------------ External zccess to library functions
}
