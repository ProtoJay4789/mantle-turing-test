// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/interfaces/IAgentRegistry.sol";

/// @title AgentRegistry
/// @notice On-chain agent identity and reputation management
/// @dev Core contract — used by every layer and adapter
/// @author Dmob (GenTech Labs)
contract AgentRegistry is IAgentRegistry, AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    uint256 private _nextAgentId;
    mapping(uint256 => Agent) private _agents;
    mapping(address => uint256) private _ownerToAgent;
    uint256 private _totalAgents;

    error AgentAlreadyRegistered();
    error AgentNotFound();
    error InvalidReputation();
    error NotAgentOwner();
    error AgentNotActive();

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /// @inheritdoc IAgentRegistry
    function registerAgent(string calldata _name, bytes32 _skillHash) external override returns (uint256 agentId) {
        if (_ownerToAgent[msg.sender] != 0) revert AgentAlreadyRegistered();

        agentId = ++_nextAgentId;
        _agents[agentId] = Agent({
            owner: msg.sender,
            name: _name,
            skillHash: _skillHash,
            reputation: 5000, // Default: 50/100
            registeredAt: block.timestamp,
            totalJobs: 0,
            active: true
        });
        _ownerToAgent[msg.sender] = agentId;
        _totalAgents++;

        emit AgentRegistered(msg.sender, agentId, _name);
        return agentId;
    }

    /// @inheritdoc IAgentRegistry
    function getAgent(uint256 _agentId) external view override returns (Agent memory agent) {
        if (_agents[_agentId].owner == address(0)) revert AgentNotFound();
        return _agents[_agentId];
    }

    /// @inheritdoc IAgentRegistry
    function getAgentByOwner(address _owner) external view override returns (uint256 agentId) {
        return _ownerToAgent[_owner];
    }

    /// @inheritdoc IAgentRegistry
    function updateReputation(uint256 _agentId, uint256 _newReputation) external override {
        if (_agents[_agentId].owner == address(0)) revert AgentNotFound();
        if (_newReputation > 10000) revert InvalidReputation();
        // Only oracle or admin can update reputation
        if (!hasRole(ORACLE_ROLE, msg.sender) && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, ORACLE_ROLE);
        }

        uint256 oldScore = _agents[_agentId].reputation;
        _agents[_agentId].reputation = _newReputation;
        emit ReputationUpdated(_agents[_agentId].owner, oldScore, _newReputation);
    }

    /// @inheritdoc IAgentRegistry
    function updateSkills(uint256 _agentId, bytes32 _skillHash) external override {
        if (_agents[_agentId].owner == address(0)) revert AgentNotFound();
        if (_agents[_agentId].owner != msg.sender) revert NotAgentOwner();

        _agents[_agentId].skillHash = _skillHash;
        emit SkillsUpdated(msg.sender, _skillHash);
    }

    /// @inheritdoc IAgentRegistry
    function isActive(uint256 _agentId) external view override returns (bool active) {
        return _agents[_agentId].active;
    }

    /// @inheritdoc IAgentRegistry
    function totalAgents() external view override returns (uint256 count) {
        return _totalAgents;
    }

    /// @notice Increment job count for agent (restricted to core contracts)
    /// @param _agentId The agent ID
    function incrementJobCount(uint256 _agentId) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert AccessControlUnauthorizedAccount(msg.sender, ADMIN_ROLE);
        _agents[_agentId].totalJobs++;
    }

    /// @notice Deactivate agent (admin only)
    /// @param _agentId The agent ID
    function deactivateAgent(uint256 _agentId) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert AccessControlUnauthorizedAccount(msg.sender, ADMIN_ROLE);
        _agents[_agentId].active = false;
    }
}
