// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IAgentRegistry.sol";

/**
 * @title ERC8004Adapter
 * @notice Integrates with the ERC-8004 Identity NFT standard on Mantle
 * @dev Wraps the Mantle IdentityRegistry to give agents on-chain identity NFTs
 * @dev IdentityRegistry: 0x8004A818BFB912233c491871b3d84c89A494BD9e (Mantle Sepolia)
 */
contract ERC8004Adapter {
    // Mantle Testnet deployment addresses
    address public constant IDENTITY_REGISTRY = 0x8004A818BFB912233c491871b3d84c89A494BD9e;
    address public constant REPUTATION_REGISTRY = 0x8004B663056A597Dffe9eCcC1965A193B7388713;

    IAgentRegistry public immutable agentRegistry;
    mapping(uint256 => address) public agentToNFT; // agentId => NFT owner
    mapping(address => uint256) public nftToAgentId; // NFT owner => agentId

    event AgentIdentityMinted(uint256 indexed agentId, address indexed agent, uint256 nftTokenId);
    event AgentIdentitySynced(uint256 indexed agentId, uint256 reputationScore);

    constructor(address _agentRegistry) {
        agentRegistry = IAgentRegistry(_agentRegistry);
    }

    /**
     * @notice Register an agent and get an ERC-8004 Identity NFT
     * @param _agentId The agent ID from AgentRegistry
     * @param _metadataURI IPFS/URL pointing to agent metadata JSON
     */
    function registerWithIdentity(uint256 _agentId, string calldata _metadataURI) external {
        require(agentToNFT[_agentId] == 0, "Identity already minted");

        // In production, this calls the Mantle IdentityRegistry
        // For hackathon demo, we track the mapping locally
        agentToNFT[_agentId] = msg.sender;
        nftToAgentId[msg.sender] = _agentId;

        emit AgentIdentityMinted(_agentId, msg.sender, _agentId);
    }

    /**
     * @notice Sync reputation score to ERC-8004 ReputationRegistry
     * @param _agentId The agent ID to sync
     */
    function syncReputation(uint256 _agentId) external {
        // Read reputation from our AgentRegistry
        // In production, this writes to the Mantle ReputationRegistry
        emit AgentIdentitySynced(_agentId, 0);
    }

    /**
     * @notice Check if an agent has an ERC-8004 identity
     */
    function hasIdentity(uint256 _agentId) external view returns (bool) {
        return agentToNFT[_agentId] != address(0);
    }

    /**
     * @notice Get agent ID from NFT holder
     */
    function getAgentId(address _holder) external view returns (uint256) {
        return nftToAgentId[_holder];
    }
}
