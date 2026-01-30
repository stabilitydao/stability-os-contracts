// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Hosted} from "../../src/base/Hosted.sol";

contract MinHostedNoReceive is Hosted {
    string public constant VERSION = "1.0.0";

    function initialize(address authority_, bytes memory) public payable initializer {
        __Hosted_init(authority_);
    }

    function testFunction() public pure returns (uint) {
        return 1;
    }

    // no receive
}
