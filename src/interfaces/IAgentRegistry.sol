// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentRegistry
/// @notice Interface for agent registration and reputation management
/// @dev Core contract — used by every layer and adapter
interface IAgentRegistry {
    /// @notice Emitted when a new agent is registered
    event AgentRegistered(address indexed agent, uint256 indexed agentId, string name);

    /// @notice Emitted when agent reputation is updated
    event ReputationUpdated(address indexed agent, uint256 oldScore, uint256 newScore);

    /// @notice Emitted when agent skills are updated
    event SkillsUpdated(address indexed agent, bytes32 skillHash);

    /// @notice Agent data structure
    struct Agent {
        address owner;
        string name;
        bytes32 skillHash; // IPFS/0G hash of skill config
        uint256 reputation; // 0-10000 scale
        uint256 registeredAt;
        uint256 totalJobs;
        bool active;
    }

    /// @notice Register a new agent
    /// @param _name Human-readable agent name
    /// @param _skillHash Hash of agent skills/config (IPFS or 0G)
    /// @return agentId The assigned agent ID
    function registerAgent(string calldata _name, bytes32 _skillHash) external returns (uint256 agentId);

    /// @notice Get agent details by ID
    /// @param _agentId The agent ID to query
    /// @return agent The agent data struct
    function getAgent(uint256 _agentId) external view returns (Agent memory agent);

    /// @notice Get agent ID by owner address
    /// @param _owner The owner address
    /// @return agentId The agent ID (0 if not registered)
    function getAgentByOwner(address _owner) external view returns (uint256 agentId);

    /// @notice Update agent reputation (restricted)
    /// @param _agentId The agent ID
    /// @param _newReputation New reputation score (0-10000)
    function updateReputation(uint256 _agentId, uint256 _newReputation) external;

    /// @notice Update agent skills hash
    /// @param _agentId The agent ID
    /// @param _skillHash New skill hash
    function updateSkills(uint256 _agentId, bytes32 _skillHash) external;

    /// @notice Check if agent is active
    /// @param _agentId The agent ID
    /// @return active Whether the agent is active
    function isActive(uint256 _agentId) external view returns (bool active);

    /// @notice Get total registered agents
    /// @return count Total agent count
    function totalAgents() external view returns (uint256 count);

    /// @notice Increment job count for agent (restricted to core contracts)
    /// @param _agentId The agent ID
    function incrementJobCount(uint256 _agentId) external;
}
