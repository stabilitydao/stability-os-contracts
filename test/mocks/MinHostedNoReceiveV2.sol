// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Hosted} from "../../src/base/Hosted.sol";

/// @notice New version of MinHostedNoReceive (for proxy upgrade testing)
contract MinHostedNoReceiveV2 is Hosted {
    string public constant VERSION = "2.0.0";

    function initialize(address authority_, bytes memory) public payable initializer {
        __Hosted_init(authority_);
    }

    // no receive

    function newFunction() public pure returns (string memory) {
        return "new function called";
    }

    function testFunction() public pure returns (uint) {
        return 1;
    }
}
