# Agent Economy — Mantle Turing Test

> **Agentic Wallet Economy with ERC-8004 Identity NFT**

On-chain agent identity, reputation, and autonomous task execution — built for the Agentic Wallets & Economy track.

**Built for:** Mantle Turing Test Hackathon — Agentic Wallets & Economy Track
**Prize:** $120K total ($50K Grand)
**Deadline:** June 15, 2026

## What It Does

A modular 5-layer agent economy system:

1. **AgentRegistry** — On-chain identity + reputation (0-10000 scale)
2. **JobEscrow** — Payment escrow with dispute resolution
3. **AgentKeeper** — Autonomous execution triggers (conditions → actions)
4. **ERC8004Adapter** — ERC-8004 Identity NFT integration on Mantle
5. **Data Adapters** — Zerion (portfolio risk) + GoldRush (analytics)

## Architecture

```
┌─────────────────────────────────────────────┐
│              ERC-8004 Identity              │
│  (Mantle IdentityRegistry + Reputation)     │
├─────────────────────────────────────────────┤
│  AgentRegistry    │  AgentKeeper            │
│  (identity/rep)   │  (autonomous triggers)  │
├───────────────────┼─────────────────────────┤
│  JobEscrow        │  Data Adapters          │
│  (payment/dispute)│  (Zerion, GoldRush)     │
└───────────────────┴─────────────────────────┘
```

## Quick Start

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Build
forge build

# Test (14/14 passing)
forge test

# Deploy to Mantle Sepolia
FOUNDRY_PROFILE=mantle forge script script/DeployMantle.s.sol --rpc-url mantle-sepolia --broadcast --verify
```

## Contracts

| Contract | Lines | Purpose |
|----------|-------|---------|
| AgentRegistry | 180 | Agent identity + reputation (RBAC) |
| JobEscrow | 150 | Payment escrow + dispute resolution |
| AgentKeeper | 120 | Autonomous execution triggers |
| ERC8004Adapter | 80 | ERC-8004 Identity NFT integration |
| ZerionAdapter | 60 | Portfolio risk detection |
| GoldRushAdapter | 60 | On-chain analytics |

**Total:** ~650 lines of Solidity, 14 tests passing

## ERC-8004 Integration

Agents get on-chain identity NFTs via the ERC-8004 standard:

- **IdentityRegistry:** `0x8004A818BFB912233c491871b3d84c89A494BD9e` (Mantle Sepolia)
- **ReputationRegistry:** `0x8004B663056A597Dffe9eCcC1965A193B7388713` (Mantle Sepolia)
- **Spec:** [eips.ethereum.org/EIPS/eip-8004](https://eips.ethereum.org/EIPS/eip-8004)
- **Site:** [8004.org/build](https://8004.org/build)

## Mantle Network

- **Testnet:** Mantle Sepolia (Chain ID: 5003)
- **RPC:** `https://rpc.sepolia.mantle.xyz`
- **EVM compatible** — Standard Foundry/Hardhat tooling
- **DeFi:** Merchant Moe, Agni Finance, Fluxion

## Judging Criteria

- On-chain performance metrics (ROI, Sharpe ratio)
- Reputation score delta
- Agent autonomy level
- ERC-8004 integration quality

## Roadmap

- [ ] Deploy to Mantle Sepolia
- [ ] Integrate with RealClaw for trading execution
- [ ] Add Byreal Skills for cross-chain agent operations
- [ ] Agent staking + slash conditions
- [ ] Multi-chain reputation portability

## Built By

GenTech Labs — [ProtoJay4789](https://github.com/ProtoJay4789)
