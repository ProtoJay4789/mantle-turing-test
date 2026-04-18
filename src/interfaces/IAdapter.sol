// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAdapter
/// @notice Base interface for all sidetrack adapters
/// @dev Thin wrapper pattern — adapters call core contracts with track-specific data
interface IAdapter {
    /// @notice Emitted when adapter processes data
    event DataProcessed(address indexed source, bytes32 indexed dataHash, uint256 timestamp);

    /// @notice Emitted when adapter triggers an action
    event ActionTriggered(address indexed agent, bytes32 indexed actionHash, bool success);

    /// @notice Get the adapter name
    /// @return name The adapter identifier
    function adapterName() external view returns (string memory name);

    /// @notice Process external data and update core contracts
    /// @param _data Encoded data from external source (Zerion, GoldRush, etc.)
    /// @return success Whether processing succeeded
    function processData(bytes calldata _data) external returns (bool success);

    /// @notice Check adapter health/status
    /// @return healthy Whether adapter is operational
    function isHealthy() external view returns (bool healthy);
}
