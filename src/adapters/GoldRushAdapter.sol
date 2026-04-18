// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "src/interfaces/IAdapter.sol";
import "src/interfaces/IAgentKeeper.sol";

/// @title GoldRushAdapter
/// @notice Adapter for Covalent GoldRush API — on-chain analytics feed
/// @dev Thin wrapper: pushes on-chain analytics data to AgentKeeper
/// @dev Target: GoldRush sidetrack ($3,000 USDC)
/// @author Dmob (GenTech Labs)
contract GoldRushAdapter is IAdapter, AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    IAgentKeeper public immutable coreContract;

    // On-chain analytics storage
    mapping(address => uint256) public lastTxCount;
    mapping(address => uint256) public lastBalance;
    mapping(address => uint256) public lastUpdateTimestamp;

    event AnalyticsUpdated(address indexed agent, uint256 txCount, uint256 balance, uint256 timestamp);

    error InvalidData();
    error NotOracle();

    /// @param _keeper Address of AgentKeeper contract
    constructor(address _keeper) {
        coreContract = IAgentKeeper(_keeper);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }

    /// @inheritdoc IAdapter
    function adapterName() external pure override returns (string memory) {
        return "GoldRush";
    }

    /// @inheritdoc IAdapter
    function processData(bytes calldata _data) external override returns (bool success) {
        if (!hasRole(ORACLE_ROLE, msg.sender)) revert NotOracle();

        // Decode: (address agent, uint256 txCount, uint256 balance)
        if (_data.length < 96) revert InvalidData();

        (address agent, uint256 txCount, uint256 balance) = abi.decode(
            _data,
            (address, uint256, uint256)
        );

        lastTxCount[agent] = txCount;
        lastBalance[agent] = balance;
        lastUpdateTimestamp[agent] = block.timestamp;

        emit AnalyticsUpdated(agent, txCount, balance, block.timestamp);
        return true;
    }

    /// @notice Get analytics for an agent
    /// @param _agent The agent address
    /// @return txCount Transaction count
    /// @return balance Current balance
    /// @return updatedAt Last update timestamp
    function getAnalytics(address _agent) external view returns (uint256 txCount, uint256 balance, uint256 updatedAt) {
        return (lastTxCount[_agent], lastBalance[_agent], lastUpdateTimestamp[_agent]);
    }

    /// @inheritdoc IAdapter
    function isHealthy() external view override returns (bool) {
        return address(coreContract) != address(0);
    }
}
