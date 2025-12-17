// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOS, OS} from "../../src/os/OS.sol";
import {ITokenomics} from "../../src/interfaces/ITokenomics.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {SonicConstantsLib} from "../../chains/SonicConstantsLib.sol";
import {console} from "forge-std/console.sol";

contract OsSonicTest is Test {
    uint public constant FORK_BLOCK = 58135155; // Dec-17-2025 05:45:24 AM +UTC

    string internal constant DAO_SYMBOL = "SPACE";
    string internal constant DAO_NAME = "SpaceSwap";

    constructor() {
        vm.selectFork(vm.createFork(vm.envString("SONIC_RPC_URL"), FORK_BLOCK));
    }

    //region ----------------------------------- Unit tests
    function testCreateDAO() public {
        IOS os = _createOsInstance();

        // -------------------- Prepare test data
        ITokenomics.Funding[] memory funding = new ITokenomics.Funding[](1);
        funding[0] = _generateSeedFunding();

        ITokenomics.Activity[] memory activity = new ITokenomics.Activity[](1);
        activity[0] = ITokenomics.Activity.DEFI_PROTOCOL_OPERATOR_0;

        ITokenomics.DaoParameters memory params = _generateDaoParams(365, 100);

        os.createDAO(DAO_NAME, DAO_SYMBOL, activity, params, funding);

        ITokenomics.DaoData memory dao = os.getDAO(DAO_SYMBOL);
        assertEq(dao.name, DAO_NAME, "expected name");
        // todo assertEq(os.eventsCount(), 1);

        // -------------------- bad name length
        vm.expectRevert(abi.encodeWithSelector(IOS.NameLength.selector, uint(28)));
        os.createDAO("SpaceSwap_000000000000000000", "SPACE2", activity, params, funding);

        // -------------------- bad symbol length
        vm.expectRevert(abi.encodeWithSelector(IOS.SymbolLength.selector, uint(9)));
        os.createDAO("SpaceSwap", "SPACESWAP", activity, params, funding);

        // -------------------- not unique symbol
        vm.expectRevert(abi.encodeWithSelector(IOS.SymbolNotUnique.selector, "SPACE"));
        os.createDAO("SpaceSwap", "SPACE", activity, params, funding);

        { // -------------------- bad vePeriod
            ITokenomics.DaoParameters memory paramsBadVe = _generateDaoParams(365 * 5 /* 1825 */, 100);
            vm.expectRevert(abi.encodeWithSelector(IOS.VePeriod.selector, uint(1825)));
            os.createDAO("SpaceSwap", "SPACE1", activity, paramsBadVe, funding);
        }

        { // -------------------- bad pvpFee
            ITokenomics.DaoParameters memory paramsBadPvP = _generateDaoParams(365, 101);
            vm.expectRevert(abi.encodeWithSelector(IOS.PvPFee.selector, uint(101)));
            os.createDAO("SpaceSwap", "SPACE1", activity, paramsBadPvP, funding);
        }

        { // -------------------- no funding
            ITokenomics.Funding[] memory emptyFunding = new ITokenomics.Funding[](0);
            vm.expectRevert(IOS.NeedFunding.selector);
            os.createDAO("SpaceSwap", "SPACE1", activity, params, emptyFunding);
        }
    }

    function testAddLiveDAO() public {

    }

    //endregion ----------------------------------- Unit tests


    //region ----------------------------------- Internal logic
    function _createOsInstance() internal returns (IOS) {
        OS os = new OS(SonicConstantsLib.MULTISIG);
        _setOsSettings(os);
        return IOS(address(os));
    }

    function _setOsSettings(OS os) internal {
        // Prepare and set OS settings using the IOS.OsSettings struct
        os.setSettings(
            IOS.OsSettings({
                priceDao: 1000,
                priceUnit: 1000,
                priceOracle: 1000,
                priceBridge: 1000,
                minNameLength: 1,
                maxNameLength: 20,
                minSymbolLength: 1,
                maxSymbolLength: 7,
                minVePeriod: 14,
                maxVePeriod: 365 * 4,
                minPvPFee: 10,
                maxPvPFee: 100,
                minFundingDuration: 1,
                maxFundingDuration: 180,
                minAbsorbOfferUsd: 50000
            })
        );
    }

    /// @notice Generate a seed funding with sensible defaults relative to current block timestamp.
    /// @return A populated ITokenomics.Funding struct ready to be passed to createDAO/updateFunding.
    function _generateSeedFunding() internal view returns (ITokenomics.Funding memory) {
        // Defaults: delaySec = 30 days, duration = 90 days, minRaise = 10_000, maxRaise = 100_000
        uint64 delaySec = uint64(30 * 86400);
        uint64 duration = uint64(3 * 30 * 86400);

        uint64 start = uint64(block.timestamp + delaySec);
        uint64 endt = uint64(block.timestamp + delaySec + duration);

        return ITokenomics.Funding({
            fundingType: ITokenomics.FundingType.SEED_0,
            start: start,
            end: endt,
            minRaise: 10000,
            maxRaise: 100000,
            raised: 0,
            claim: 0
        });
    }

    function _generateDaoParams(uint32 vePeriod_, uint16 pvpFee_) internal pure returns (ITokenomics.DaoParameters memory) {
        return ITokenomics.DaoParameters({
            vePeriod: vePeriod_,
            pvpFee: pvpFee_,
            minPower: 0,
            ttBribe: 0,
            recoveryShare: 0,
            proposalThreshold: 0
        });
    }

    //endregion ----------------------------------- Internal logic
}