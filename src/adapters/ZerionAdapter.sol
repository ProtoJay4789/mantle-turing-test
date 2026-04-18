// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "src/interfaces/IAdapter.sol";
import "src/interfaces/IAgentKeeper.sol";

/// @title ZerionAdapter
/// @notice Adapter for Zerion CLI integration — portfolio risk → agent triggers
/// @dev Thin wrapper: reads portfolio data, pushes to AgentKeeper
/// @dev Target: Zerion CLI sidetrack ($5,000 USDC)
/// @author Dmob (GenTech Labs)
contract ZerionAdapter is IAdapter, AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    IAgentKeeper public immutable coreContract;
    address public immutable zerionGateway;

    // Portfolio tracking
    mapping(address => uint256) public lastPortfolioValue; // agent => total USD value
    mapping(address => uint256) public lastUpdateTimestamp;

    event PortfolioUpdated(address indexed agent, uint256 totalValue, uint256 timestamp);
    event RiskTriggered(address indexed agent, uint256 threshold, uint256 currentValue);

    error InvalidData();
    error StaleData();
    error NotOracle();

    /// @param _keeper Address of AgentKeeper contract
    /// @param _zerionGateway Zerion API gateway address (or oracle relayer)
    constructor(address _keeper, address _zerionGateway) {
        coreContract = IAgentKeeper(_keeper);
        zerionGateway = _zerionGateway;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }

    /// @inheritdoc IAdapter
    function adapterName() external pure override returns (string memory) {
        return "ZerionCLI";
    }

    /// @inheritdoc IAdapter
    function processData(bytes calldata _data) external override returns (bool success) {
        if (!hasRole(ORACLE_ROLE, msg.sender)) revert NotOracle();

        // Decode: (address agent, uint256 portfolioValue, uint256 threshold)
        if (_data.length < 96) revert InvalidData();

        (address agent, uint256 portfolioValue, uint256 threshold) = abi.decode(
            _data,
            (address, uint256, uint256)
        );

        lastPortfolioValue[agent] = portfolioValue;
        lastUpdateTimestamp[agent] = block.timestamp;

        emit PortfolioUpdated(agent, portfolioValue, block.timestamp);

        // Check if portfolio dropped below threshold (risk trigger)
        if (portfolioValue < threshold) {
            emit RiskTriggered(agent, threshold, portfolioValue);
            // Oracle can then call checkAndExecute on keeper with this agent's conditions
        }

        return true;
    }

    /// @notice Check portfolio risk for an agent
    /// @param _agent The agent address
    /// @param _threshold Risk threshold (USD value, 8 decimals)
    /// @return atRisk Whether portfolio is below threshold
    function checkRisk(address _agent, uint256 _threshold) external view returns (bool atRisk) {
        if (lastUpdateTimestamp[_agent] == 0) return false;
        // Data older than 1 hour is stale
        if (block.timestamp - lastUpdateTimestamp[_agent] > 1 hours) revert StaleData();

        return lastPortfolioValue[_agent] < _threshold;
    }

    /// @notice Get portfolio data for an agent
    /// @param _agent The agent address
    /// @return value Portfolio USD value
    /// @return updatedAt Last update timestamp
    function getPortfolio(address _agent) external view returns (uint256 value, uint256 updatedAt) {
        return (lastPortfolioValue[_agent], lastUpdateTimestamp[_agent]);
    }

    /// @inheritdoc IAdapter
    function isHealthy() external view override returns (bool) {
        return zerionGateway != address(0);
    }
}
