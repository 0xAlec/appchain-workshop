// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BattleRoyaleFactory.sol";
import "../src/BotFactory.sol";
import "../src/OffchainBot.sol";

contract DeployScript is Script {
    function run() external {
        // Use a hardcoded private key for testing
        // This is the default anvil private key, do not use in production
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the battle royale factory
        BattleRoyaleFactory battleRoyaleFactory = new BattleRoyaleFactory();
        
        // Deploy the bot factory
        BotFactory botFactory = new BotFactory();
        
        // Log the addresses
        console.log("BattleRoyaleFactory deployed at:", address(battleRoyaleFactory));
        console.log("BotFactory deployed at:", address(botFactory));
        
        // Deploy a sample game
        address gameAddress = battleRoyaleFactory.deployGame();
        console.log("Sample game deployed at:", gameAddress);
        
        // Get the rewards contract for the sample game
        address rewardsAddress = battleRoyaleFactory.getRewardsContract(gameAddress);
        console.log("Sample game rewards contract deployed at:", rewardsAddress);
        
        // Deploy a sample bot
        address botAddress = botFactory.deployBot();
        console.log("Sample bot deployed at:", botAddress);
        
        vm.stopBroadcast();
    }
} 