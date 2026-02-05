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
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";

contract HostProposalLibTest is Test {
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
            IHost.BridgedActions.SET_BRIDGED_UNIT_2,
            IHost.BridgedActions.REMOVE_BRIDGED_UNIT_3,
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
    function _getSampleProposalPayload() internal view returns (bytes memory) {
        ITokenomics.DaoImages memory data =
            ITokenomics.DaoImages({seedToken: "1", tgeToken: "22", token: "333", xToken: "4444", daoToken: "55555"});

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

    //    function _setupAuthority(IAuthority authority_, address seedToken_, address tgeToken_) internal {
    //        bytes4[] memory selectors = new bytes4[](3);
    //        selectors[0] = bytes4(SeedToken.mint.selector);
    //        selectors[1] = bytes4(SeedToken.refund.selector);
    //        selectors[2] = bytes4(SeedToken.transferTo.selector);
    //
    //        vm.prank(multisig);
    //        authority_.setTargetFunctionRole(seedToken_, selectors, 65871739); // 65871739 = random role uid
    //
    //        selectors = new bytes4[](2);
    //        selectors[0] = bytes4(TgeToken.mint.selector);
    //        selectors[1] = bytes4(TgeToken.refund.selector);
    //
    //        vm.prank(multisig);
    //        authority_.setTargetFunctionRole(tgeToken_, selectors, 65871739);
    //
    //        vm.prank(multisig);
    //        authority_.grantRole(65871739, multisig, 0);
    //
    //        vm.prank(multisig);
    //        authority_.grantRole(65871739, address(this), 0);
    //    }

    //endregion ------------------------------------------ Internal logic
}
