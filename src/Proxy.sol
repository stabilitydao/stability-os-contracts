// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Proxy as OpenZeppelinProxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IProxy} from "./interfaces/IProxy.sol";

/// @notice This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
/// implementation address that can be changed. This address is stored in storage in the location specified by
/// https://eips.ethereum.org/EIPS/eip-1967[ERC-1967], so that it doesn't conflict with the storage layout of the
/// implementation behind the proxy.
/// @dev The implementation of the contract is exactly same to OpenZeppelin ERC1967Proxy
/// but it has initProxy function instead of constructor to be able to create proxy through Clones
/// and to create proxy using create2 with deterministic address that doesn't depend on implementation
/// @author omriss (https://github.com/omriss)
contract Proxy is OpenZeppelinProxy, IProxy {
    /// @inheritdoc IProxy
    function initProxy(address implementation_, bytes memory data_) external payable {
        require(_implementation() == address(0), ProxyAlreadyInitialized());

        ERC1967Utils.upgradeToAndCall(implementation_, data_);
    }

    /// @inheritdoc IProxy
    function implementation() external view returns (address) {
        return _implementation();
    }

    /// @dev Returns the current implementation address.
    ///
    /// TIP: To get this value clients can read directly from the storage slot shown below (specified by ERC-1967) using
    /// the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
    /// `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
    function _implementation() internal view virtual override returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /// @dev Fallback function that delegates calls to the address returned by `_implementation()`.
    /// Will run if call data is empty.
    //slither-disable-next-line locked-ether
    receive() external payable {
        _fallback();
    }
}
