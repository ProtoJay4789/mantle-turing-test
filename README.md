# AAE — Agent Economy (Solana Frontier + Sidetracks)

> 5 modular layers. 1 codebase. Multiple hackathon submissions.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AAE Agent Economy                         │
├─────────────────────────────────────────────────────────────┤
│  Layer 5: Cross-Agent Coordination (TaskManager)            │
│  Layer 4: Social Leaderboards / Reputation                  │
│  Layer 3: Brain (Evolve/Learn/Memory)                       │
│  Layer 2: Agent Risk Intelligence (AgentKeeper) ← SIDETRACK │
│  Layer 1: Fee LP Auto-Balance                               │
├─────────────────────────────────────────────────────────────┤
│  Foundation: AgentRegistry + JobEscrow + Marketplace        │
├─────────────────────────────────────────────────────────────┤
│  ADAPTERS: Zerion │ GoldRush │ Dune │ KeeperHub             │
└─────────────────────────────────────────────────────────────┘
```

## Contracts

### Core (Foundation)
| Contract | Description | Status |
|----------|-------------|--------|
| `AgentRegistry.sol` | Agent identity + reputation (0-10000) | ✅ Built |
| `JobEscrow.sol` | Payment escrow with dispute resolution | ✅ Built |

### Layer 2: Risk Intelligence
| Contract | Description | Status |
|----------|-------------|--------|
| `AgentKeeper.sol` | Autonomous execution triggers | ✅ Built |

### Adapters (Sidetrack Wrappers)
| Contract | Sidetrack | Prize | Status |
|----------|-----------|-------|--------|
| `ZerionAdapter.sol` | Zerion CLI | $5,000 USDC | ✅ Built |
| `GoldRushAdapter.sol` | Covalent GoldRush | $3,000 USDC | ✅ Built |

## Test Coverage

Run tests:
```bash
forge test -vvv
```

Current: **20+ tests** covering:
- Agent registration + reputation
- Job escrow lifecycle (create → accept → complete → release)
- Dispute resolution
- Keeper conditions (register → trigger → execute)
- Zerion portfolio risk detection
- GoldRush analytics integration
- Full integration flow

## Deploy

```bash
forge script script/DeployAgentEconomy.s.sol --rpc-url $RPC_URL --broadcast
```

## Hackathon Targets

| Event | Deadline | Prize | Layer |
|-------|----------|-------|-------|
| Superteam Earn (Zerion CLI) | May 11 | $5,000 | L2+L5 |
| Superteam Earn (GoldRush) | May 11 | $3,000 | L2 |
| Superteam Earn (Dune) | May 11 | TBD | L2 |
| Superteam Earn (Agentic) | May 11 | ~200 USDG | L3 |
| Solana Frontier (main) | May 11 | $230K+ | All |
| ETHGlobal Open Agents | May 3 | $50K | L2+L3+L4+L5 |

## Design Principles

- **Checks-effects-interactions** — always
- **Pull-over-push** — users withdraw, don't receive pushes
- **Gas discipline** — calldata over memory, custom errors
- **OpenZeppelin base** — AccessControl, ReentrancyGuard, SafeERC20
- **Adapter pattern** — thin wrappers per sidetrack, core shared
- **Events everywhere** — every state change emits

## Project Structure

```
src/
├── core/                    # Foundation contracts
│   ├── AgentRegistry.sol
│   └── JobEscrow.sol
├── layers/                  # AAE layers
│   ├── L1-LP/
│   ├── L2-Risk/
│   │   └── AgentKeeper.sol
│   ├── L3-Brain/
│   ├── L4-Social/
│   └── L5-Coord/
├── adapters/                # Sidetrack adapters
│   ├── ZerionAdapter.sol
│   └── GoldRushAdapter.sol
└── interfaces/              # Contract interfaces
    ├── IAgentRegistry.sol
    ├── IJobEscrow.sol
    ├── IAgentKeeper.sol
    └── IAdapter.sol
```

## Tags
#AAE #solana #frontier #hackathon #agents #DeFi #foundry
