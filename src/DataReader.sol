// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAuthority} from "./interfaces/IAuthority.sol";
import {IDAOData} from "./interfaces/IDAOData.sol";
import {IHost} from "./interfaces/IHost.sol";
import {Hosted} from "./base/Hosted.sol";
import {IHosted} from "./interfaces/IHosted.sol";
import {IDataReader} from "./interfaces/IDataReader.sol";
import {HostEncodingLib} from "./libs/HostEncodingLib.sol";

/// @notice DataReader takes data from Host in binary and provide access to them in human readable format.
/// @dev DAO-related data is large and complex,
/// Host is not able to provide direct access to them w/o increasing contract size significantly.
contract DataReader is IDataReader, Hosted {
    /// @inheritdoc IHosted
    string public constant VERSION = "1.0.0";

    /// @inheritdoc IHosted
    function initialize(address authority_, bytes memory) public payable initializer {
        __Hosted_init(authority_);
    }

    /// @inheritdoc IDataReader
    function getDAO(string calldata symbol) external view returns (IDAOData.DaoData memory dest) {
        bytes memory data = _host()
            .getBinaryData(uint(IHost.DataReaderItem.DAO_DATA_0), abi.encode(symbol), HostEncodingLib.API_VERSION);
        return HostEncodingLib.decodeDAOData(data);
    }

    /// @inheritdoc IDataReader
    function proposal(bytes32 proposalId) external view returns (IDAOData.Proposal memory dest) {
        bytes memory data = _host()
            .getBinaryData(uint(IHost.DataReaderItem.PROPOSAL_1), abi.encode(proposalId), HostEncodingLib.API_VERSION);
        return HostEncodingLib.decodeProposal(data);
    }

    /// @notice IDataReader
    function getTokenName(uint daoUid, uint namingTokenKind) external view returns (string memory) {
        bytes memory data = _host()
            .getBinaryData(
                uint(IHost.DataReaderItem.DAO_NAME_2), abi.encode(daoUid, namingTokenKind), HostEncodingLib.API_VERSION
            );
        return abi.decode(data, (string));
    }

    /// @notice IDataReader
    function getTokenSymbol(uint daoUid, uint namingTokenKind) external view returns (string memory) {
        bytes memory data = _host()
            .getBinaryData(
                uint(IHost.DataReaderItem.DAO_SYMBOL_3),
                abi.encode(daoUid, namingTokenKind),
                HostEncodingLib.API_VERSION
            );
        return abi.decode(data, (string));
    }

    function _host() internal view returns (IHost) {
        return IHost(IAuthority(authority()).HOST());
    }
}
