// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BattleRoyale.sol";
import "./BattleRoyaleRewards.sol";

/**
 * @title BattleRoyaleFactory
 * @dev Factory contract to deploy new battle royale games
 */
contract BattleRoyaleFactory {
    address public owner;
    
    // Array to store all deployed battle royale games
    BattleRoyale[] public deployedGames;
    
    // Mapping from battle royale address to rewards contract
    mapping(address => address) public gameToRewards;
    
    // Events
    event GameDeployed(address indexed gameAddress, address indexed rewardsAddress, address indexed deployer);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Deploy a new battle royale game
     * @return Address of the deployed game
     */
    function deployGame() external returns (address) {
        // Deploy battle royale contract
        BattleRoyale newGame = new BattleRoyale();
        
        // Transfer ownership of the game to the deployer
        // Use a low-level call to avoid interface issues
        (bool success, ) = address(newGame).call(
            abi.encodeWithSignature("transferOwnership(address)", msg.sender)
        );
        require(success, "Ownership transfer failed");
        
        // Deploy rewards contract
        BattleRoyaleRewards newRewards = new BattleRoyaleRewards(address(newGame));
        
        // Store deployed game
        deployedGames.push(newGame);
        
        // Store mapping from game to rewards
        gameToRewards[address(newGame)] = address(newRewards);
        
        emit GameDeployed(address(newGame), address(newRewards), msg.sender);
        
        return address(newGame);
    }
    
    /**
     * @dev Get all deployed games
     * @return Array of deployed game addresses
     */
    function getDeployedGames() external view returns (BattleRoyale[] memory) {
        return deployedGames;
    }
    
    /**
     * @dev Get rewards contract for a game
     * @param _gameAddress Address of the battle royale game
     * @return Address of the rewards contract
     */
    function getRewardsContract(address _gameAddress) external view returns (address) {
        return gameToRewards[_gameAddress];
    }
    
    /**
     * @dev Transfer ownership
     * @param _newOwner New owner address
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }
} 