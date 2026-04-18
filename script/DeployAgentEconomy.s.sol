// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/AgentRegistry.sol";
import "../src/core/JobEscrow.sol";
import "../src/layers/L2-Risk/AgentKeeper.sol";
import "../src/adapters/ZerionAdapter.sol";
import "../src/adapters/GoldRushAdapter.sol";

/// @title DeployAgentEconomy
/// @notice Deploy the full AAE stack: core + layer + adapters
contract DeployAgentEconomy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Core contracts
        AgentRegistry registry = new AgentRegistry();
        JobEscrow escrow = new JobEscrow(address(registry));
        AgentKeeper keeper = new AgentKeeper(address(registry));

        // Step 2: Adapters
        ZerionAdapter zerionAdapter = new ZerionAdapter(address(keeper), address(0)); // Update gateway later
        GoldRushAdapter goldRushAdapter = new GoldRushAdapter(address(keeper));

        // Step 3: Configure roles
        registry.grantRole(registry.ORACLE_ROLE(), address(keeper));
        keeper.grantRole(keeper.ORACLE_ROLE(), address(zerionAdapter));
        keeper.grantRole(keeper.ORACLE_ROLE(), address(goldRushAdapter));

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("=== AAE Deployment ===");
        console.log("AgentRegistry:", address(registry));
        console.log("JobEscrow:", address(escrow));
        console.log("AgentKeeper:", address(keeper));
        console.log("ZerionAdapter:", address(zerionAdapter));
        console.log("GoldRushAdapter:", address(goldRushAdapter));
    }
}
