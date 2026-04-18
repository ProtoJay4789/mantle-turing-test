// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/interfaces/IJobEscrow.sol";
import "src/interfaces/IAgentRegistry.sol";

/// @title JobEscrow
/// @notice Payment escrow for agent jobs with dispute resolution
/// @dev Foundation layer — handles all agent-to-agent and client-to-agent payments
/// @author Dmob (GenTech Labs)
contract JobEscrow is IJobEscrow, AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ARBITRATOR_ROLE = keccak256("ARBITRATOR_ROLE");

    IAgentRegistry public immutable registry;

    uint256 private _nextJobId;
    mapping(uint256 => Job) private _jobs;
    uint256 private _totalJobs;

    error JobNotFound();
    error NotJobClient();
    error NotJobAgent();
    error InvalidJobState();
    error DeadlineNotReached();
    error InsufficientPayment();

    modifier onlyJobClient(uint256 _jobId) {
        if (_jobs[_jobId].client != msg.sender) revert NotJobClient();
        _;
    }

    modifier onlyJobAgent(uint256 _jobId) {
        if (_jobs[_jobId].agent != msg.sender) revert NotJobAgent();
        _;
    }

    modifier inState(uint256 _jobId, JobState _state) {
        if (_jobs[_jobId].state != _state) revert InvalidJobState();
        _;
    }

    constructor(address _registry) {
        registry = IAgentRegistry(_registry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /// @inheritdoc IJobEscrow
    function createJob(
        address _agent,
        uint256 _deadline,
        string calldata _description
    ) external payable override nonReentrant returns (uint256 jobId) {
        if (msg.value == 0) revert InsufficientPayment();

        jobId = ++_nextJobId;
        _jobs[jobId] = Job({
            jobId: jobId,
            client: msg.sender,
            agent: _agent,
            payment: msg.value,
            state: JobState.Created,
            createdAt: block.timestamp,
            deadline: _deadline,
            description: _description
        });
        _totalJobs++;

        emit JobCreated(jobId, msg.sender, _agent, msg.value);
        return jobId;
    }

    /// @inheritdoc IJobEscrow
    function acceptJob(uint256 _jobId) external override onlyJobAgent(_jobId) inState(_jobId, JobState.Created) {
        _jobs[_jobId].state = JobState.Accepted;
        emit JobAccepted(_jobId, msg.sender);
    }

    /// @inheritdoc IJobEscrow
    function completeJob(uint256 _jobId) external override onlyJobAgent(_jobId) inState(_jobId, JobState.Accepted) {
        _jobs[_jobId].state = JobState.Completed;
        emit JobCompleted(_jobId, msg.sender);
    }

    /// @inheritdoc IJobEscrow
    function releasePayment(uint256 _jobId) external override onlyJobClient(_jobId) nonReentrant {
        JobState state = _jobs[_jobId].state;
        if (state != JobState.Completed && state != JobState.Resolved) revert InvalidJobState();

        uint256 payment = _jobs[_jobId].payment;
        address agent = _jobs[_jobId].agent;

        // Pull-over-push: agent withdraws, we don't push
        _jobs[_jobId].payment = 0;
        _jobs[_jobId].state = JobState.Resolved;

        (bool success, ) = agent.call{value: payment}("");
        require(success, "Payment transfer failed");

        // Update agent job count
        uint256 agentId = registry.getAgentByOwner(agent);
        if (agentId != 0) {
            registry.incrementJobCount(agentId);
        }

        emit PaymentReleased(_jobId, agent, payment);
    }

    /// @inheritdoc IJobEscrow
    function disputeJob(uint256 _jobId, string calldata _reason) external override {
        JobState state = _jobs[_jobId].state;
        if (
            msg.sender != _jobs[_jobId].client &&
            msg.sender != _jobs[_jobId].agent
        ) revert NotJobClient();
        if (state != JobState.Accepted && state != JobState.Completed) revert InvalidJobState();

        _jobs[_jobId].state = JobState.Disputed;
        emit JobDisputed(_jobId, msg.sender);
    }

    /// @notice Resolve dispute (arbitrator only)
    /// @param _jobId The job ID
    /// @param _releaseToAgent If true, release to agent; if false, refund client
    function resolveDispute(uint256 _jobId, bool _releaseToAgent) external {
        if (!hasRole(ARBITRATOR_ROLE, msg.sender) && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, ARBITRATOR_ROLE);
        }
        if (_jobs[_jobId].state != JobState.Disputed) revert InvalidJobState();

        uint256 payment = _jobs[_jobId].payment;
        address recipient = _releaseToAgent ? _jobs[_jobId].agent : _jobs[_jobId].client;

        _jobs[_jobId].payment = 0;
        _jobs[_jobId].state = JobState.Resolved;

        (bool success, ) = recipient.call{value: payment}("");
        require(success, "Resolution transfer failed");

        emit PaymentReleased(_jobId, recipient, payment);
    }

    /// @notice Auto-release payment (keeper only, for completed jobs)
    /// @dev Designed for keeper-triggered automation
    /// @param _jobId The job ID
    function autoReleasePayment(uint256 _jobId) external nonReentrant {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert AccessControlUnauthorizedAccount(msg.sender, ADMIN_ROLE);
        JobState state = _jobs[_jobId].state;
        if (state != JobState.Completed) revert InvalidJobState();

        uint256 payment = _jobs[_jobId].payment;
        address agent = _jobs[_jobId].agent;

        _jobs[_jobId].payment = 0;
        _jobs[_jobId].state = JobState.Resolved;

        (bool success, ) = agent.call{value: payment}("");
        require(success, "Payment transfer failed");

        uint256 agentId = registry.getAgentByOwner(agent);
        if (agentId != 0) {
            registry.incrementJobCount(agentId);
        }

        emit PaymentReleased(_jobId, agent, payment);
    }

    /// @inheritdoc IJobEscrow
    function getJob(uint256 _jobId) external view override returns (Job memory job) {
        if (_jobs[_jobId].client == address(0)) revert JobNotFound();
        return _jobs[_jobId];
    }

    /// @inheritdoc IJobEscrow
    function totalJobs() external view override returns (uint256 count) {
        return _totalJobs;
    }
}
