// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentKeeper
/// @notice Interface for autonomous agent execution triggers
/// @dev Layer 2: Agents monitor conditions and execute when triggered
interface IAgentKeeper {
    /// @notice Emitted when a condition is registered
    event ConditionRegistered(uint256 indexed conditionId, address indexed agent, address target);

    /// @notice Emitted when condition is triggered and execution happens
    event ConditionTriggered(uint256 indexed conditionId, address indexed agent);

    /// @notice Emitted when condition is cancelled
    event ConditionCancelled(uint256 indexed conditionId, address indexed agent);

    /// @notice Condition types
    enum ConditionType { PriceAbove, PriceBelow, TimeElapsed, Custom }

    /// @notice Condition data structure
    struct Condition {
        uint256 conditionId;
        address agent;
        address target; // Contract to call
        bytes callData; // Encoded function call
        ConditionType conditionType;
        uint256 threshold; // Price threshold or time (depending on type)
        bool active;
        uint256 createdAt;
    }

    /// @notice Register a new execution condition
    /// @param _target Contract to call when triggered
    /// @param _callData Encoded function call
    /// @param _conditionType Type of condition
    /// @param _threshold Threshold value
    /// @return conditionId The created condition ID
    function registerCondition(
        address _target,
        bytes calldata _callData,
        ConditionType _conditionType,
        uint256 _threshold
    ) external returns (uint256 conditionId);

    /// @notice Check if condition is met and execute
    /// @param _conditionId The condition ID
    /// @return triggered Whether execution happened
    function checkAndExecute(uint256 _conditionId) external returns (bool triggered);

    /// @notice Cancel a condition
    /// @param _conditionId The condition ID
    function cancelCondition(uint256 _conditionId) external;

    /// @notice Get condition details
    /// @param _conditionId The condition ID
    /// @return condition The condition data
    function getCondition(uint256 _conditionId) external view returns (Condition memory condition);

    /// @notice Get all conditions for an agent
    /// @param _agent The agent address
    /// @return conditionIds Array of condition IDs
    function getAgentConditions(address _agent) external view returns (uint256[] memory conditionIds);

    /// @notice Get total active conditions
    /// @return count Total active conditions
    function totalConditions() external view returns (uint256 count);
}
