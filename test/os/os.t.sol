// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOS, OS} from "../../src/os/OS.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {SonicConstantsLib} from "../../chains/SonicConstantsLib.sol";


contract OsSonicTest is Test {
    uint public constant FORK_BLOCK = 58135155; // Dec-17-2025 05:45:24 AM +UTC

    string internal constant DAO_SYMBOL = "SPACE";
    string internal constant DAO_NAME = "SpaceSwap";

    constructor() {
        vm.selectFork(vm.createFork(vm.envString("SONIC_RPC_URL"), FORK_BLOCK));
    }

    //region ----------------------------------- Unit tests
    function testCreateDAO() public {
        IOS os = createOsInstance();

        // -------------------- Prepare test data
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = ITokenomics.Funding({
            fundingType: ITokenomics.FundingType.SEED_0,
            start: 1800000000,
            end: 1805000000,
            minRaise: 20000,
            maxRaise: 1000000,
            raised: 0,
            claim: 0
        });

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = ITokenomics.DaoParameters({
            vePeriod: 180,
            pvpFee: 20_00,
            minPower: 4000e18,
            ttBribe: 30_000,
            recoveryShare: 20_000,
            proposalThreshold: 15_000
        });

        os.createDAO(DAO_NAME, DAO_SYMBOL, activity, params, funding);

        ITokenomics.DaoData memory dao = os.getDAO(DAO_SYMBOL);
        assertEq(dao.name, DAO_NAME, "expected name");
        // todo assertEq(os.eventsCount(), 1);

        // -------------------- bad name length
        vm.expectRevert(bytes("NameLength(28)"));
        os.createDAO("SpaceSwap_000000000000000000", "SPACE2", activity, params, funding);

        // -------------------- bad symbol length
        vm.expectRevert(bytes("SymbolLength(9)"));
        os.createDAO("SpaceSwap", "SPACESWAP", activity, params, funding);

        // -------------------- not unique symbol
        vm.expectRevert(bytes("SymbolNotUnique(SPACE)"));
        os.createDAO("SpaceSwap", "SPACE", activity, params, funding);

        // -------------------- bad vePeriod
        ITokenomics.DaoParameters memory paramsBadVe = params;
        paramsBadVe.vePeriod = 365 * 5; // 1825
        vm.expectRevert(bytes("VePeriod(1825)"));
        os.createDAO("SpaceSwap", "SPACE1", activity, paramsBadVe, funding);

        // -------------------- bad pvpFee
        ITokenomics.DaoParameters memory paramsBadPvP = params;
        paramsBadPvP.pvpFee = 101;
        vm.expectRevert(bytes("PvPFee(101)"));
        os.createDAO("SpaceSwap", "SPACE1", activity, paramsBadPvP, funding);

        // -------------------- no funding
        ITokenomics.Funding[] memory emptyFunding = new ITokenomics.Funding[](0);
        vm.expectRevert(bytes("NeedFunding"));
        os.createDAO("SpaceSwap", "SPACE1", activity, params, emptyFunding);
    }


    //endregion ----------------------------------- Unit tests


    //region ----------------------------------- Internal logic
    function createOsInstance() internal returns (IOS) {
        OS os = new OS(SonicConstantsLib.MULTISIG);
        return IOS(address(os));
    }

    //endregion ----------------------------------- Internal logic
}