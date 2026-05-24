// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/AgentRegistry.sol";
import "../src/core/JobEscrow.sol";
import "../src/layers/L2-Risk/AgentKeeper.sol";
import "../src/adapters/ERC8004Adapter.sol";

contract DeployMantleEconomy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy core
        AgentRegistry registry = new AgentRegistry();
        JobEscrow escrow = new JobEscrow(address(registry));
        AgentKeeper keeper = new AgentKeeper(address(registry));

        // Deploy ERC-8004 adapter
        ERC8004Adapter erc8004 = new ERC8004Adapter(address(registry));

        // Setup roles
        registry.grantRole(registry.ADMIN_ROLE(), address(escrow));
        registry.grantRole(registry.ORACLE_ROLE(), address(keeper));
        keeper.grantRole(keeper.ORACLE_ROLE(), oracle);

        console.log("AgentRegistry:", address(registry));
        console.log("JobEscrow:", address(escrow));
        console.log("AgentKeeper:", address(keeper));
        console.log("ERC8004Adapter:", address(erc8004));

        vm.stopBroadcast();
    }
}
