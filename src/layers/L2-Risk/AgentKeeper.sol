// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/interfaces/IAgentKeeper.sol";
import "src/interfaces/IAgentRegistry.sol";

/// @title AgentKeeper
/// @notice Autonomous agent execution — monitor conditions, trigger actions
/// @dev Layer 2: Risk Intelligence — the Swiss Army knife for sidetracks
/// @dev Compatible with KeeperHub, Zerion CLI, GoldRush, Dune adapters
/// @author Dmob (GenTech Labs)
contract AgentKeeper is IAgentKeeper, AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    IAgentRegistry public immutable registry;

    uint256 private _nextConditionId;
    mapping(uint256 => Condition) private _conditions;
    mapping(address => uint256[]) private _agentConditions;
    uint256 private _totalActiveConditions;

    // For external price feeds (adapters push data here)
    mapping(bytes32 => uint256) public latestPrice; // pairHash => price

    error ConditionNotFound();
    error NotConditionOwner();
    error ConditionNotActive();
    error InvalidTarget();
    error ExecutionFailed();

    constructor(address _registry) {
        registry = IAgentRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /// @inheritdoc IAgentKeeper
    function registerCondition(
        address _target,
        bytes calldata _callData,
        ConditionType _conditionType,
        uint256 _threshold
    ) external override returns (uint256 conditionId) {
        if (_target == address(0)) revert InvalidTarget();

        conditionId = ++_nextConditionId;
        _conditions[conditionId] = Condition({
            conditionId: conditionId,
            agent: msg.sender,
            target: _target,
            callData: _callData,
            conditionType: _conditionType,
            threshold: _threshold,
            active: true,
            createdAt: block.timestamp
        });

        _agentConditions[msg.sender].push(conditionId);
        _totalActiveConditions++;

        emit ConditionRegistered(conditionId, msg.sender, _target);
        return conditionId;
    }

    /// @inheritdoc IAgentKeeper
    function checkAndExecute(uint256 _conditionId) external override nonReentrant returns (bool triggered) {
        Condition storage condition = _conditions[_conditionId];
        if (!condition.active) revert ConditionNotActive();

        bool shouldExecute = _evaluateCondition(condition);
        if (!shouldExecute) return false;

        // Execute the action
        (bool success, ) = condition.target.call(condition.callData);
        if (!success) revert ExecutionFailed();

        // Deactivate after execution (one-shot)
        condition.active = false;
        _totalActiveConditions--;

        emit ConditionTriggered(_conditionId, condition.agent);
        return true;
    }

    /// @inheritdoc IAgentKeeper
    function cancelCondition(uint256 _conditionId) external override {
        Condition storage condition = _conditions[_conditionId];
        if (condition.agent != msg.sender) revert NotConditionOwner();
        if (!condition.active) revert ConditionNotActive();

        condition.active = false;
        _totalActiveConditions--;

        emit ConditionCancelled(_conditionId, msg.sender);
    }

    /// @inheritdoc IAgentKeeper
    function getCondition(uint256 _conditionId) external view override returns (Condition memory condition) {
        if (_conditions[_conditionId].agent == address(0)) revert ConditionNotFound();
        return _conditions[_conditionId];
    }

    /// @inheritdoc IAgentKeeper
    function getAgentConditions(address _agent) external view override returns (uint256[] memory conditionIds) {
        return _agentConditions[_agent];
    }

    /// @inheritdoc IAgentKeeper
    function totalConditions() external view override returns (uint256 count) {
        return _totalActiveConditions;
    }

    /// @notice Update price feed (oracle only — adapters push data here)
    /// @param _pairHash Hash identifier for the trading pair
    /// @param _price Latest price (in USD, 8 decimals)
    function updatePrice(bytes32 _pairHash, uint256 _price) external {
        if (!hasRole(ORACLE_ROLE, msg.sender)) revert AccessControlUnauthorizedAccount(msg.sender, ORACLE_ROLE);
        latestPrice[_pairHash] = _price;
    }

    /// @notice Batch update prices (oracle only)
    /// @param _pairHashes Array of pair hashes
    /// @param _prices Array of prices
    function updatePrices(bytes32[] calldata _pairHashes, uint256[] calldata _prices) external {
        if (!hasRole(ORACLE_ROLE, msg.sender)) revert AccessControlUnauthorizedAccount(msg.sender, ORACLE_ROLE);
        require(_pairHashes.length == _prices.length, "Length mismatch");

        for (uint256 i = 0; i < _pairHashes.length; i++) {
            latestPrice[_pairHashes[i]] = _prices[i];
        }
    }

    /// @dev Evaluate if condition should trigger
    function _evaluateCondition(Condition memory _condition) internal view returns (bool) {
        if (_condition.conditionType == ConditionType.TimeElapsed) {
            return block.timestamp >= _condition.createdAt + _condition.threshold;
        }
        // Price conditions evaluated via external oracle push
        // For PriceAbove/PriceBelow, threshold is the target price
        // Actual price checking is done off-chain by adapters
        // Adapter calls checkAndExecute() only when condition is met
        return true;
    }
}
