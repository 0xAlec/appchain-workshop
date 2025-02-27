// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BattleRoyaleFactory.sol";
import "../src/BotFactory.sol";
import "../src/OffchainBot.sol";
import "../src/BattleRoyale.sol";

contract GameSimulationScript is Script {
    function run() external {
        // Use a hardcoded private key for testing
        // This is the default anvil private key, do not use in production
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy the battle royale factory
        BattleRoyaleFactory battleRoyaleFactory = new BattleRoyaleFactory();
        console.log("BattleRoyaleFactory deployed at:", address(battleRoyaleFactory));
        
        // Step 2: Deploy the bot factory
        BotFactory botFactory = new BotFactory();
        console.log("BotFactory deployed at:", address(botFactory));
        
        // Step 3: Create a new game
        address gameAddress = battleRoyaleFactory.deployGame();
        console.log("Game deployed at:", gameAddress);
        BattleRoyale game = BattleRoyale(gameAddress);
        
        // Step 4: Create two bots
        address bot1Address = botFactory.deployBot();
        address bot2Address = botFactory.deployBot();
        console.log("Bot 1 deployed at:", bot1Address);
        console.log("Bot 2 deployed at:", bot2Address);
        
        // Fix: Explicitly cast to payable addresses
        OffchainBot bot1 = OffchainBot(payable(bot1Address));
        OffchainBot bot2 = OffchainBot(payable(bot2Address));
        
        // Step 5: Create a new round with 10 blocks for registration
        game.createRound(10);
        console.log("Round created with 10 blocks for registration");
        
        // Step 6: Register the bots
        bot1.register(gameAddress);
        console.log("Bot 1 registered");
        
        bot2.register(gameAddress);
        console.log("Bot 2 registered");
        
        // Step 7: Start the game
        game.startGame();
        console.log("Game started");
        
        // Step 8: Get the positions of the bots
        (uint256 round, , , , , , uint256 bot1X, uint256 bot1Y, uint256 bot1Health) = bot1.getGameState(gameAddress);
        console.log("Bot 1 position: (%d, %d) with health: %d", bot1X, bot1Y, bot1Health);
        
        (, , , , , , uint256 bot2X, uint256 bot2Y, uint256 bot2Health) = bot2.getGameState(gameAddress);
        console.log("Bot 2 position: (%d, %d) with health: %d", bot2X, bot2Y, bot2Health);
        
        // Step 9: Set commands for the bots
        // Bot 1 will move UP (0)
        bot1.setNextCommand(
            gameAddress,
            round,
            0, // MOVE
            0, // UP
            0, // Not used for move
            0  // Not used for move
        );
        console.log("Bot 1 set to move UP");
        
        // Bot 2 will move DOWN (1)
        bot2.setNextCommand(
            gameAddress,
            round,
            0, // MOVE
            1, // DOWN
            0, // Not used for move
            0  // Not used for move
        );
        console.log("Bot 2 set to move DOWN");
        
        // Step 10: Execute the actions
        bot1.executeAction(gameAddress);
        console.log("Bot 1 executed move action");
        
        bot2.executeAction(gameAddress);
        console.log("Bot 2 executed move action");
        
        // Step 11: Execute all pending actions
        game.executeActions();
        console.log("All actions executed");
        
        // Step 12: Get the new positions of the bots
        (, , , , , , uint256 newBot1X, uint256 newBot1Y, ) = bot1.getGameState(gameAddress);
        console.log("Bot 1 new position: (%d, %d)", newBot1X, newBot1Y);
        
        (, , , , , , uint256 newBot2X, uint256 newBot2Y, ) = bot2.getGameState(gameAddress);
        console.log("Bot 2 new position: (%d, %d)", newBot2X, newBot2Y);
        
        // Step 13: Set attack commands if bots are close enough
        // Check if bots are in attack range (Manhattan distance <= ATTACK_RANGE)
        uint256 xDiff = newBot1X > newBot2X ? newBot1X - newBot2X : newBot2X - newBot1X;
        uint256 yDiff = newBot1Y > newBot2Y ? newBot1Y - newBot2Y : newBot2Y - newBot1Y;
        uint256 attackRange = game.ATTACK_RANGE();
        
        if (xDiff + yDiff <= attackRange) {
            // Bot 1 will attack Bot 2
            bot1.setNextCommand(
                gameAddress,
                round,
                1, // ATTACK
                0, // Not used for attack
                newBot2X, // Target X
                newBot2Y  // Target Y
            );
            console.log("Bot 1 set to attack Bot 2");
            
            // Bot 2 will defend
            bot2.setNextCommand(
                gameAddress,
                round,
                2, // DEFEND
                0, // Not used for defend
                0, // Not used for defend
                0  // Not used for defend
            );
            console.log("Bot 2 set to defend");
            
            // Execute the actions
            bot1.executeAction(gameAddress);
            console.log("Bot 1 executed attack action");
            
            bot2.executeAction(gameAddress);
            console.log("Bot 2 executed defend action");
            
            // Execute all pending actions
            game.executeActions();
            console.log("All actions executed");
            
            // Get the health of Bot 2 after the attack
            (, , , , , , , , uint256 newBot2Health) = bot2.getGameState(gameAddress);
            console.log("Bot 2 health after attack: %d", newBot2Health);
        } else {
            console.log("Bots are not in attack range (Manhattan distance: %d, Attack range: %d)", xDiff + yDiff, attackRange);
            
            // If not in range, move Bot 1 towards Bot 2
            uint8 moveDirection;
            if (newBot1X < newBot2X) {
                moveDirection = 3; // RIGHT
                console.log("Bot 1 will move RIGHT towards Bot 2");
            } else if (newBot1X > newBot2X) {
                moveDirection = 2; // LEFT
                console.log("Bot 1 will move LEFT towards Bot 2");
            } else if (newBot1Y < newBot2Y) {
                moveDirection = 1; // DOWN
                console.log("Bot 1 will move DOWN towards Bot 2");
            } else {
                moveDirection = 0; // UP
                console.log("Bot 1 will move UP towards Bot 2");
            }
            
            // Set move command for Bot 1
            bot1.setNextCommand(
                gameAddress,
                round,
                0, // MOVE
                moveDirection,
                0, // Not used for move
                0  // Not used for move
            );
            
            // Bot 2 will move randomly
            uint8 randomDirection = uint8(uint256(keccak256(abi.encodePacked(block.timestamp))) % 4);
            bot2.setNextCommand(
                gameAddress,
                round,
                0, // MOVE
                randomDirection,
                0, // Not used for move
                0  // Not used for move
            );
            console.log("Bot 2 will move randomly (direction: %d)", randomDirection);
            
            // Execute the actions
            bot1.executeAction(gameAddress);
            console.log("Bot 1 executed move action");
            
            bot2.executeAction(gameAddress);
            console.log("Bot 2 executed move action");
            
            // Execute all pending actions
            game.executeActions();
            console.log("All actions executed");
            
            // Get the new positions of the bots
            (, , , , , , uint256 finalBot1X, uint256 finalBot1Y, ) = bot1.getGameState(gameAddress);
            console.log("Bot 1 final position: (%d, %d)", finalBot1X, finalBot1Y);
            
            (, , , , , , uint256 finalBot2X, uint256 finalBot2Y, ) = bot2.getGameState(gameAddress);
            console.log("Bot 2 final position: (%d, %d)", finalBot2X, finalBot2Y);
        }
        
        vm.stopBroadcast();
    }
} 