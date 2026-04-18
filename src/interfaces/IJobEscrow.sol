// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IJobEscrow
/// @notice Interface for job escrow management
/// @dev Handles payment escrow between agents/clients
interface IJobEscrow {
    /// @notice Emitted when a new job is created
    event JobCreated(uint256 indexed jobId, address indexed client, address indexed agent, uint256 payment);

    /// @notice Emitted when job is accepted by agent
    event JobAccepted(uint256 indexed jobId, address indexed agent);

    /// @notice Emitted when job is completed
    event JobCompleted(uint256 indexed jobId, address indexed agent);

    /// @notice Emitted when payment is released
    event PaymentReleased(uint256 indexed jobId, address indexed agent, uint256 amount);

    /// @notice Emitted when job is disputed
    event JobDisputed(uint256 indexed jobId, address indexed disputer);

    /// @notice Job states
    enum JobState { Created, Accepted, Completed, Disputed, Resolved, Cancelled }

    /// @notice Job data structure
    struct Job {
        uint256 jobId;
        address client;
        address agent;
        uint256 payment;
        JobState state;
        uint256 createdAt;
        uint256 deadline;
        string description;
    }

    /// @notice Create a new job with escrow payment
    /// @param _agent Address of the agent to hire
    /// @param _deadline Job deadline (unix timestamp)
    /// @param _description Job description
    /// @return jobId The created job ID
    function createJob(address _agent, uint256 _deadline, string calldata _description) external payable returns (uint256 jobId);

    /// @notice Agent accepts the job
    /// @param _jobId The job ID
    function acceptJob(uint256 _jobId) external;

    /// @notice Mark job as completed
    /// @param _jobId The job ID
    function completeJob(uint256 _jobId) external;

    /// @notice Release payment to agent (client confirms completion)
    /// @param _jobId The job ID
    function releasePayment(uint256 _jobId) external;

    /// @notice Dispute a job
    /// @param _jobId The job ID
    /// @param _reason Dispute reason
    function disputeJob(uint256 _jobId, string calldata _reason) external;

    /// @notice Get job details
    /// @param _jobId The job ID
    /// @return job The job data struct
    function getJob(uint256 _jobId) external view returns (Job memory job);

    /// @notice Get total jobs
    /// @return count Total job count
    function totalJobs() external view returns (uint256 count);
}
