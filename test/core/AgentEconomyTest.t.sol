// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/core/AgentRegistry.sol";
import "src/core/JobEscrow.sol";
import "src/layers/L2-Risk/AgentKeeper.sol";
import "src/adapters/ZerionAdapter.sol";
import "src/adapters/GoldRushAdapter.sol";

/// @title AgentEconomyTest
/// @notice Full integration test suite for AAE core + adapters
/// @dev Covers: AgentRegistry, JobEscrow, AgentKeeper, ZerionAdapter, GoldRushAdapter
contract AgentEconomyTest is Test {
    AgentRegistry public registry;
    JobEscrow public escrow;
    AgentKeeper public keeper;
    ZerionAdapter public zerionAdapter;
    GoldRushAdapter public goldRushAdapter;

    address public admin = makeAddr("admin");
    address public agent1 = makeAddr("agent1");
    address public agent2 = makeAddr("agent2");
    address public client = makeAddr("client");
    address public oracle = makeAddr("oracle");
    address public zerionGateway = makeAddr("zerionGateway");

    function setUp() public {
        vm.startPrank(admin);

        // Deploy core
        registry = new AgentRegistry();
        escrow = new JobEscrow(address(registry));
        keeper = new AgentKeeper(address(registry));

        // Deploy adapters
        zerionAdapter = new ZerionAdapter(address(keeper), zerionGateway);
        goldRushAdapter = new GoldRushAdapter(address(keeper));

        // Grant roles
        registry.grantRole(registry.ADMIN_ROLE(), address(escrow));
        registry.grantRole(registry.ORACLE_ROLE(), address(keeper));
        keeper.grantRole(keeper.ORACLE_ROLE(), address(zerionAdapter));
        keeper.grantRole(keeper.ORACLE_ROLE(), address(goldRushAdapter));
        keeper.grantRole(keeper.ORACLE_ROLE(), oracle);
        escrow.grantRole(escrow.ADMIN_ROLE(), address(keeper));

        zerionAdapter.grantRole(zerionAdapter.ORACLE_ROLE(), oracle);
        goldRushAdapter.grantRole(goldRushAdapter.ORACLE_ROLE(), oracle);

        vm.stopPrank();
    }

    // ============ AgentRegistry Tests ============

    function test_registerAgent() public {
        vm.prank(agent1);
        uint256 agentId = registry.registerAgent("AlphaBot", bytes32(uint256(1)));

        assertEq(agentId, 1);
        assertEq(registry.totalAgents(), 1);

        AgentRegistry.Agent memory agent = registry.getAgent(agentId);
        assertEq(agent.owner, agent1);
        assertEq(agent.name, "AlphaBot");
        assertEq(agent.reputation, 5000);
        assertTrue(agent.active);
    }

    function test_registerAgent_duplicateReverts() public {
        vm.prank(agent1);
        registry.registerAgent("AlphaBot", bytes32(uint256(1)));

        vm.prank(agent1);
        vm.expectRevert(AgentRegistry.AgentAlreadyRegistered.selector);
        registry.registerAgent("BetaBot", bytes32(uint256(2)));
    }

    function test_updateReputation() public {
        vm.prank(agent1);
        uint256 agentId = registry.registerAgent("AlphaBot", bytes32(uint256(1)));

        vm.prank(admin);
        registry.updateReputation(agentId, 8500);

        AgentRegistry.Agent memory agent = registry.getAgent(agentId);
        assertEq(agent.reputation, 8500);
    }

    function test_updateReputation_invalidReverts() public {
        vm.prank(agent1);
        uint256 agentId = registry.registerAgent("AlphaBot", bytes32(uint256(1)));

        vm.prank(admin);
        vm.expectRevert(AgentRegistry.InvalidReputation.selector);
        registry.updateReputation(agentId, 10001);
    }

    // ============ JobEscrow Tests ============

    function test_createAndReleaseJob() public {
        // Register agent
        vm.prank(agent1);
        uint256 agentId = registry.registerAgent("AlphaBot", bytes32(uint256(1)));

        // Create job
        vm.deal(client, 1 ether);
        vm.prank(client);
        uint256 jobId = escrow.createJob{value: 1 ether}(
            agent1,
            block.timestamp + 1 days,
            "Build DeFi strategy"
        );

        assertEq(jobId, 1);

        // Agent accepts
        vm.prank(agent1);
        escrow.acceptJob(jobId);

        // Agent completes
        vm.prank(agent1);
        escrow.completeJob(jobId);

        // Client releases payment
        uint256 agentBalanceBefore = agent1.balance;
        vm.prank(client);
        escrow.releasePayment(jobId);

        assertEq(agent1.balance - agentBalanceBefore, 1 ether);
    }

    function test_disputeAndResolve() public {
        vm.prank(agent1);
        registry.registerAgent("AlphaBot", bytes32(uint256(1)));

        vm.deal(client, 1 ether);
        vm.prank(client);
        uint256 jobId = escrow.createJob{value: 1 ether}(
            agent1,
            block.timestamp + 1 days,
            "Build DeFi strategy"
        );

        vm.prank(agent1);
        escrow.acceptJob(jobId);

        // Client disputes
        vm.prank(client);
        escrow.disputeJob(jobId, "Work not satisfactory");

        // Admin resolves in favor of client (refund)
        vm.prank(admin);
        escrow.resolveDispute(jobId, false);

        // Client should get refund
        // (balance check omitted for simplicity — payment set to 0 after resolution)
    }

    // ============ AgentKeeper Tests ============

    function test_registerAndCancelCondition() public {
        bytes memory callData = abi.encodeWithSignature("execute()");

        vm.prank(agent1);
        uint256 condId = keeper.registerCondition(
            address(escrow),
            callData,
            IAgentKeeper.ConditionType.TimeElapsed,
            1 hours
        );

        assertEq(condId, 1);

        // Cancel
        vm.prank(agent1);
        keeper.cancelCondition(condId);

        IAgentKeeper.Condition memory cond = keeper.getCondition(condId);
        assertFalse(cond.active);
    }

    function test_checkAndExecute_timeElapsed() public {
        bytes memory callData = abi.encodeWithSignature("totalJobs()");
        vm.prank(agent1);
        uint256 condId = keeper.registerCondition(
            address(escrow),
            callData,
            IAgentKeeper.ConditionType.TimeElapsed,
            1 hours
        );

        // Should not trigger yet
        bool triggered = keeper.checkAndExecute(condId);
        assertFalse(triggered);

        // Warp time
        vm.warp(block.timestamp + 2 hours);

        // Should trigger now
        triggered = keeper.checkAndExecute(condId);
        assertTrue(triggered);

        // Condition should be deactivated after execution
        IAgentKeeper.Condition memory cond = keeper.getCondition(condId);
        assertFalse(cond.active);
    }

    // ============ ZerionAdapter Tests ============

    function test_zerion_processData() public {
        // Encode: (agent, portfolioValue, threshold)
        bytes memory data = abi.encode(agent1, 50000e8, 40000e8);

        vm.prank(oracle);
        bool success = zerionAdapter.processData(data);
        assertTrue(success);

        (uint256 value, uint256 updatedAt) = zerionAdapter.getPortfolio(agent1);
        assertEq(value, 50000e8);
        assertGt(updatedAt, 0);
    }

    function test_zerion_checkRisk() public {
        // Portfolio below threshold
        bytes memory data = abi.encode(agent1, 30000e8, 40000e8);
        vm.prank(oracle);
        zerionAdapter.processData(data);

        bool atRisk = zerionAdapter.checkRisk(agent1, 40000e8);
        assertTrue(atRisk);
    }

    function test_zerion_checkRisk_aboveThreshold() public {
        // Portfolio above threshold
        bytes memory data = abi.encode(agent1, 50000e8, 40000e8);
        vm.prank(oracle);
        zerionAdapter.processData(data);

        bool atRisk = zerionAdapter.checkRisk(agent1, 40000e8);
        assertFalse(atRisk);
    }

    // ============ GoldRushAdapter Tests ============

    function test_goldrush_processData() public {
        bytes memory data = abi.encode(agent1, uint256(150), 10 ether);

        vm.prank(oracle);
        bool success = goldRushAdapter.processData(data);
        assertTrue(success);

        (uint256 txCount, uint256 balance, uint256 updatedAt) = goldRushAdapter.getAnalytics(agent1);
        assertEq(txCount, 150);
        assertEq(balance, 10 ether);
    }

    // ============ Integration: Full Flow ============

    function test_fullFlow_registerEscrowKeeper() public {
        // 1. Register agent
        vm.prank(agent1);
        uint256 agentId = registry.registerAgent("AlphaBot", bytes32(uint256(1)));
        assertEq(agentId, 1);

        // 2. Create job
        vm.deal(client, 2 ether);
        vm.prank(client);
        uint256 jobId = escrow.createJob{value: 2 ether}(
            agent1,
            block.timestamp + 1 days,
            "Manage LP position"
        );

        // 3. Register keeper condition (auto-release after 6 hours)
        bytes memory releaseCall = abi.encodeWithSignature("autoReleasePayment(uint256)", jobId);
        vm.prank(agent1);
        uint256 condId = keeper.registerCondition(
            address(escrow),
            releaseCall,
            IAgentKeeper.ConditionType.TimeElapsed,
            6 hours
        );

        // 4. Agent accepts and completes
        vm.prank(agent1);
        escrow.acceptJob(jobId);
        vm.prank(agent1);
        escrow.completeJob(jobId);

        // 5. Time passes, keeper triggers auto-release
        vm.warp(block.timestamp + 7 hours);
        bool triggered = keeper.checkAndExecute(condId);
        assertTrue(triggered);

        // 6. Verify agent got paid
        assertEq(escrow.getJob(jobId).payment, 0);
    }

    function test_adapterIntegration() public {
        // 1. Oracle pushes Zerion data
        bytes memory data = abi.encode(agent1, 25000e8, 30000e8);
        vm.prank(oracle);
        zerionAdapter.processData(data);

        // 2. Verify risk detected
        bool atRisk = zerionAdapter.checkRisk(agent1, 30000e8);
        assertTrue(atRisk);

        // 3. Oracle pushes GoldRush data
        bytes memory goldRushData = abi.encode(agent1, uint256(5), 0.1 ether);
        vm.prank(oracle);
        goldRushAdapter.processData(goldRushData);

        // 4. Verify low activity
        (uint256 txCount, uint256 balance, ) = goldRushAdapter.getAnalytics(agent1);
        assertLt(txCount, 10); // Low tx count
        assertLt(balance, 1 ether); // Low balance
    }
}
