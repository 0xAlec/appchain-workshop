// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./OffchainBot.sol";

/**
 * @title BotFactory
 * @dev Factory contract to deploy new battle royale bots
 */
contract BotFactory {
    address public owner;
    
    // Array to store all deployed bots
    address[] public deployedBots;
    
    // Mapping from user to their bots
    mapping(address => address[]) public userBots;
    
    // Events
    event BotDeployed(address indexed botAddress, address indexed deployer);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Deploy a new bot
     * @return Address of the deployed bot
     */
    function deployBot() external returns (address) {
        // Deploy bot contract
        OffchainBot newBot = new OffchainBot();
        
        // Transfer ownership to the deployer
        newBot.transferOwnership(msg.sender);
        
        // Store deployed bot
        deployedBots.push(address(newBot));
        
        // Store mapping from user to bot
        userBots[msg.sender].push(address(newBot));
        
        emit BotDeployed(address(newBot), msg.sender);
        
        return address(newBot);
    }
    
    /**
     * @dev Get all deployed bots
     * @return Array of deployed bot addresses
     */
    function getDeployedBots() external view returns (address[] memory) {
        return deployedBots;
    }
    
    /**
     * @dev Get all bots deployed by a user
     * @param _user User address
     * @return Array of bot addresses
     */
    function getUserBots(address _user) external view returns (address[] memory) {
        return userBots[_user];
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